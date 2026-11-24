// service/CardRecommendationService.java
package com.example.choi.recommendation.service;

import com.example.choi.AssetService;
import com.example.choi.recommendation.dto.CardBenefitRule;
import com.example.choi.recommendation.dto.CardPromotionRule;
import com.example.choi.recommendation.dto.CardSimulationResult;
import com.example.choi.recommendation.dto.NormalizedTransaction;
import com.example.choi.recommendation.dto.RecommendationCardProfile;
import com.example.choi.recommendation.dto.RecommendedCardItem;
import com.example.choi.recommendation.dto.RecommendedCardResponse;
import com.example.choi.recommendation.dto.TransactionBenefitDetail;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CardRecommendationService {

    private final AssetService assetService;
    private final CategoryNormalizer categoryNormalizer;
    private final MerchantNormalizer merchantNormalizer;
    private final RecommendationCatalogProvider catalogProvider;

    private static final DateTimeFormatter[] DATE_FORMATTERS = new DateTimeFormatter[]{
            DateTimeFormatter.ISO_LOCAL_DATE_TIME,
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"),
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS"),
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS")
    };

    private static final Set<String> GENERIC_MERCHANT_TOKENS = Set.of(
            "점", "매장", "본점", "직영점",
            "주유소", "충전소", "주차장",
            "편의점", "마트", "백화점",
            "store", "shop", "branch"
    );

    public Mono<RecommendedCardResponse> recommendCards(String userEmail, String token) {
    Mono<Map<String, Object>> assetsMono = assetService.getIntegratedAssets(userEmail, token);
    Mono<List<RecommendationCardProfile>> cardsMono = catalogProvider.getAllCards();

    return Mono.zip(assetsMono, cardsMono)
            .map(tuple -> {
                Map<String, Object> data = tuple.getT1();
                List<RecommendationCardProfile> allCards = tuple.getT2();

                List<Map<String, Object>> rawTransactions =
                        castListMap(data.getOrDefault("transactions", Collections.emptyList()));

                List<NormalizedTransaction> transactions = normalizeTransactions(rawTransactions);
                List<NormalizedTransaction> currentMonthExpenses = filterCurrentMonthExpenses(transactions);

                BigDecimal previousMonthSpend = calculatePreviousMonthSpend(transactions);

                Map<String, BigDecimal> spendingByCategory = aggregateSpendingByCategory(currentMonthExpenses);
                List<String> topCategories = spendingByCategory.entrySet().stream()
                        .sorted(Map.Entry.<String, BigDecimal>comparingByValue().reversed())
                        .limit(3)
                        .map(Map.Entry::getKey)
                        .toList();

                List<RecommendedCardItem> recommendedCards = allCards.stream()
                        .map(card -> simulateCard(card, currentMonthExpenses, topCategories, previousMonthSpend))
                        .sorted(
                                    Comparator.comparing(CardSimulationResult::getScore, Comparator.nullsLast(Integer::compareTo)).reversed()
                                            .thenComparing(CardSimulationResult::getEstimatedSaving, Comparator.nullsLast(Long::compareTo)).reversed()
                                            .thenComparing(CardSimulationResult::getBenefitCoveragePercent, Comparator.nullsLast(Integer::compareTo)).reversed()
                            )
                        .limit(3)
                        .map(this::toRecommendedCardItem)
                        .toList();

                return RecommendedCardResponse.builder()
                        .userEmail(userEmail)
                        .analyzedMonth(YearMonth.now().toString())
                        .topCategories(topCategories)
                        .recommendedCards(recommendedCards)
                        .build();
            });
    }

    private CardSimulationResult simulateCard(
            RecommendationCardProfile card,
            List<NormalizedTransaction> transactions,
            List<String> topCategories,
            BigDecimal previousMonthSpend
    ) {
        BigDecimal totalSaving = BigDecimal.ZERO;
        int matchedTransactionCount = 0;
        int promotionMatchedCount = 0;

        Map<String, BigDecimal> savingByCategory = new HashMap<>();
        List<String> benefitDetails = new ArrayList<>();
        List<String> appliedPromotions = new ArrayList<>();
        List<TransactionBenefitDetail> topSavingCandidates = new ArrayList<>();

        Map<String, BigDecimal> benefitMonthlyUsage = new HashMap<>();
        Map<String, Integer> benefitMonthlyCount = new HashMap<>();

        Map<String, BigDecimal> promoMonthlyUsage = new HashMap<>();
        Map<String, Integer> promoMonthlyCount = new HashMap<>();

        List<CardBenefitRule> benefits = safeList(card.getBenefits());
        List<CardPromotionRule> promotions = safeList(card.getPromotions());

        for (NormalizedTransaction tx : transactions) {
            String txCategory = categoryNormalizer.normalize(tx.getCategory());
            String txMerchant = merchantNormalizer.normalize(tx.getMerchant());

            BenefitApplied bestBenefitApplied = null;

            for (int i = 0; i < benefits.size(); i++) {
                CardBenefitRule benefit = benefits.get(i);
                if (benefit == null || !benefit.isActive()) continue;
                if (!matchesBenefit(tx, benefit)) continue;

                String benefitKey = "BENEFIT_" + card.getCardId() + "_" + i;

                BenefitApplied applied = calculateBenefitApplied(
                        tx,
                        benefit,
                        benefitKey,
                        previousMonthSpend,
                        benefitMonthlyUsage,
                        benefitMonthlyCount
                );

                if (!applied.applied()) continue;

                if (bestBenefitApplied == null || applied.saving().compareTo(bestBenefitApplied.saving()) > 0) {
                    bestBenefitApplied = applied;
                }
            }

            List<PromotionApplied> matchedPromotionAppliedList = new ArrayList<>();

            for (int i = 0; i < promotions.size(); i++) {
                CardPromotionRule promo = promotions.get(i);
                if (promo == null) continue;
                if (!isPromotionApplicable(card, promo)) continue;
                if (!isPromotionPeriodValid(promo)) continue;
                if (!matchesPromotion(tx, promo)) continue;

                String promoKey = "PROMO_" + card.getCardId() + "_" + i;

                PromotionApplied applied = calculatePromotionApplied(
                        tx,
                        promo,
                        promoKey,
                        promoMonthlyUsage,
                        promoMonthlyCount
                );

                if (applied.applied()) {
                    matchedPromotionAppliedList.add(applied);
                }
            }

            BigDecimal baseSaving = bestBenefitApplied == null ? BigDecimal.ZERO : bestBenefitApplied.saving();

            BigDecimal promoSaving = BigDecimal.ZERO;
            List<PromotionApplied> finalPromotionAppliedList = new ArrayList<>();

            for (PromotionApplied promoApplied : matchedPromotionAppliedList) {
                boolean stackable = promoApplied.rule().getStackableWithBaseBenefit() == null
                        || promoApplied.rule().getStackableWithBaseBenefit();

                if (stackable) {
                    promoSaving = promoSaving.add(promoApplied.saving());
                    finalPromotionAppliedList.add(promoApplied);
                }
            }

            if (!finalPromotionAppliedList.isEmpty()) {
                BigDecimal nonStackableBest = BigDecimal.ZERO;
                PromotionApplied bestNonStackable = null;

                for (PromotionApplied promoApplied : matchedPromotionAppliedList) {
                    boolean stackable = promoApplied.rule().getStackableWithBaseBenefit() == null
                            || promoApplied.rule().getStackableWithBaseBenefit();

                    if (!stackable && promoApplied.saving().compareTo(nonStackableBest) > 0) {
                        nonStackableBest = promoApplied.saving();
                        bestNonStackable = promoApplied;
                    }
                }

                if (bestNonStackable != null && nonStackableBest.compareTo(baseSaving) > 0) {
                    baseSaving = BigDecimal.ZERO;
                    promoSaving = promoSaving.add(nonStackableBest);
                    finalPromotionAppliedList.add(bestNonStackable);
                }
            } else {
                BigDecimal nonStackableBest = BigDecimal.ZERO;
                PromotionApplied bestNonStackable = null;

                for (PromotionApplied promoApplied : matchedPromotionAppliedList) {
                    boolean stackable = promoApplied.rule().getStackableWithBaseBenefit() == null
                            || promoApplied.rule().getStackableWithBaseBenefit();

                    if (!stackable && promoApplied.saving().compareTo(nonStackableBest) > 0) {
                        nonStackableBest = promoApplied.saving();
                        bestNonStackable = promoApplied;
                    }
                }

                if (bestNonStackable != null && nonStackableBest.compareTo(baseSaving) > 0) {
                    baseSaving = BigDecimal.ZERO;
                    promoSaving = nonStackableBest;
                    finalPromotionAppliedList.add(bestNonStackable);
                }
            }

            BigDecimal txSaving = baseSaving.add(promoSaving);

            if (txSaving.compareTo(BigDecimal.ZERO) > 0) {
                matchedTransactionCount++;
                totalSaving = totalSaving.add(txSaving);

                savingByCategory.put(
                        txCategory,
                        savingByCategory.getOrDefault(txCategory, BigDecimal.ZERO).add(txSaving)
                );

                if (bestBenefitApplied != null && bestBenefitApplied.saving().compareTo(BigDecimal.ZERO) > 0 && baseSaving.compareTo(BigDecimal.ZERO) > 0) {
                    benefitMonthlyUsage.put(
                            bestBenefitApplied.ruleKey(),
                            benefitMonthlyUsage.getOrDefault(bestBenefitApplied.ruleKey(), BigDecimal.ZERO).add(bestBenefitApplied.saving())
                    );
                    benefitMonthlyCount.put(
                            bestBenefitApplied.ruleKey(),
                            benefitMonthlyCount.getOrDefault(bestBenefitApplied.ruleKey(), 0) + 1
                    );

                    benefitDetails.add(
                            txMerchant + " / "
                                    + txCategory + " / "
                                    + defaultString(bestBenefitApplied.rule().getDescription(), "기본 혜택")
                                    + " → "
                                    + toLongWon(bestBenefitApplied.saving()) + "원"
                    );

                    topSavingCandidates.add(TransactionBenefitDetail.builder()
                            .merchant(txMerchant)
                            .category(txCategory)
                            .transactionAmount(toLongWon(tx.getAmount()))
                            .savingAmount(toLongWon(bestBenefitApplied.saving()))
                            .sourceType("BENEFIT")
                            .title(defaultString(bestBenefitApplied.rule().getDescription(), "기본 혜택"))
                            .build());
                }

                for (PromotionApplied promoApplied : finalPromotionAppliedList) {
                    promoMonthlyUsage.put(
                            promoApplied.ruleKey(),
                            promoMonthlyUsage.getOrDefault(promoApplied.ruleKey(), BigDecimal.ZERO).add(promoApplied.saving())
                    );
                    promoMonthlyCount.put(
                            promoApplied.ruleKey(),
                            promoMonthlyCount.getOrDefault(promoApplied.ruleKey(), 0) + 1
                    );

                    promotionMatchedCount++;

                    appliedPromotions.add(
                            txMerchant + " / "
                                    + defaultString(promoApplied.rule().getTitle(), "프로모션")
                                    + " → "
                                    + toLongWon(promoApplied.saving()) + "원"
                    );

                    topSavingCandidates.add(TransactionBenefitDetail.builder()
                            .merchant(txMerchant)
                            .category(txCategory)
                            .transactionAmount(toLongWon(tx.getAmount()))
                            .savingAmount(toLongWon(promoApplied.saving()))
                            .sourceType("PROMOTION")
                            .title(defaultString(promoApplied.rule().getTitle(), "프로모션"))
                            .build());
                }
            }
        }

        List<String> matchedCategories = savingByCategory.entrySet().stream()
                .sorted(Map.Entry.<String, BigDecimal>comparingByValue().reversed())
                .map(Map.Entry::getKey)
                .toList();

        matchedCategories = reorderByTopCategories(matchedCategories, topCategories);

        int totalTransactionCount = transactions.size();
        int coveragePercent = totalTransactionCount == 0
                ? 0
                : (int) Math.round((matchedTransactionCount * 100.0) / totalTransactionCount);

        List<TransactionBenefitDetail> topSavingTransactions = topSavingCandidates.stream()
                .collect(Collectors.toMap(
                        detail -> detail.getMerchant() + "|" + detail.getTransactionAmount() + "|" + detail.getTitle() + "|" + detail.getSourceType(),
                        detail -> detail,
                        (d1, d2) -> {
                            long s1 = d1.getSavingAmount() == null ? 0L : d1.getSavingAmount();
                            long s2 = d2.getSavingAmount() == null ? 0L : d2.getSavingAmount();
                            return s1 >= s2 ? d1 : d2;
                        },
                        LinkedHashMap::new
                ))
                .values()
                .stream()
                .sorted(Comparator.comparing(TransactionBenefitDetail::getSavingAmount, Comparator.nullsLast(Long::compareTo)).reversed())
                .limit(3)
                .toList();

        long estimatedSaving = toLongWon(totalSaving);

        int score = buildScore(
                estimatedSaving,
                coveragePercent,
                matchedCategories,
                topCategories,
                promotionMatchedCount
        );

        String reasonSummary = buildReasonSummary(
                matchedCategories,
                estimatedSaving,
                matchedTransactionCount,
                totalTransactionCount,
                promotionMatchedCount
        );

        benefitDetails = benefitDetails.stream().distinct().limit(5).toList();
        appliedPromotions = appliedPromotions.stream().distinct().limit(7).toList();

        return CardSimulationResult.builder()
                .cardProfile(card)
                .estimatedSaving(estimatedSaving)
                .score(score)
                .matchedTransactionCount(matchedTransactionCount)
                .totalTransactionCount(totalTransactionCount)
                .benefitCoveragePercent(coveragePercent)
                .matchedCategories(matchedCategories)
                .benefitDetails(benefitDetails)
                .appliedPromotions(appliedPromotions)
                .topSavingTransactions(topSavingTransactions)
                .reasonSummary(reasonSummary)
                .build();
    }

    private BenefitApplied calculateBenefitApplied(
            NormalizedTransaction tx,
            CardBenefitRule rule,
            String ruleKey,
            BigDecimal previousMonthSpend,
            Map<String, BigDecimal> monthlyUsage,
            Map<String, Integer> monthlyCount
    ) {
        if (!isPreviousMonthSpendEligible(previousMonthSpend, rule.getPreviousMonthSpendMin(), rule.getPreviousMonthSpendMax())) {
            return BenefitApplied.notApplied(rule, ruleKey);
        }

        if (!matchesChannel(tx.getChannel(), rule.getEligibleChannels())) {
            return BenefitApplied.notApplied(rule, ruleKey);
        }

        if (!isMinAmountSatisfied(tx.getAmount(), rule.getPerTransactionMinAmount())) {
            return BenefitApplied.notApplied(rule, ruleKey);
        }

        if (!isCountAvailable(rule.getMaxBenefitCountPerMonth(), monthlyCount.get(ruleKey))) {
            return BenefitApplied.notApplied(rule, ruleKey);
        }

        BigDecimal effectiveAmount = applyPerTransactionMax(tx.getAmount(), rule.getPerTransactionMaxAmount());

        BigDecimal rawSaving = calculateSaving(
                effectiveAmount,
                rule.getBenefitType(),
                rule.getBenefitValue()
        );

        BigDecimal limitedSaving = applyMonthlyLimit(
                rawSaving,
                rule.getMonthlyBenefitLimit(),
                monthlyUsage.get(ruleKey)
        );

        if (limitedSaving.compareTo(BigDecimal.ZERO) <= 0) {
            return BenefitApplied.notApplied(rule, ruleKey);
        }

        return new BenefitApplied(true, rule, ruleKey, limitedSaving);
    }

    private PromotionApplied calculatePromotionApplied(
            NormalizedTransaction tx,
            CardPromotionRule rule,
            String ruleKey,
            Map<String, BigDecimal> monthlyUsage,
            Map<String, Integer> monthlyCount
    ) {
        if (!matchesChannel(tx.getChannel(), rule.getPromotionChannel())) {
            return PromotionApplied.notApplied(rule, ruleKey);
        }

        if (!isMinAmountSatisfied(tx.getAmount(), rule.getPromotionMinAmount())) {
            return PromotionApplied.notApplied(rule, ruleKey);
        }

        if (!isCountAvailable(rule.getPromotionMaxCount(), monthlyCount.get(ruleKey))) {
            return PromotionApplied.notApplied(rule, ruleKey);
        }

        BigDecimal rawSaving = calculateSaving(
                tx.getAmount(),
                rule.getBenefitType(),
                rule.getBenefitValue()
        );

        BigDecimal limitedByBenefitAmount = applyAbsoluteCap(rawSaving, rule.getPromotionMaxBenefitAmount());

        BigDecimal finalSaving = limitedByBenefitAmount.compareTo(BigDecimal.ZERO) < 0
                ? BigDecimal.ZERO
                : limitedByBenefitAmount;

        if (finalSaving.compareTo(BigDecimal.ZERO) <= 0) {
            return PromotionApplied.notApplied(rule, ruleKey);
        }

        return new PromotionApplied(true, rule, ruleKey, finalSaving);
    }

    private RecommendedCardItem toRecommendedCardItem(CardSimulationResult result) {
        RecommendationCardProfile card = result.getCardProfile();

        return RecommendedCardItem.builder()
                .cardId(card.getCardId())
                .cardName(card.getCardName())
                .bankName(card.getBankName())
                .cardType(card.getCardType())
                .estimatedSaving(result.getEstimatedSaving())
                .score(result.getScore())
                .matchedTransactionCount(result.getMatchedTransactionCount())
                .totalTransactionCount(result.getTotalTransactionCount())
                .benefitCoveragePercent(result.getBenefitCoveragePercent())
                .matchedCategories(result.getMatchedCategories())
                .benefitDetails(result.getBenefitDetails())
                .appliedPromotions(result.getAppliedPromotions())
                .topSavingTransactions(result.getTopSavingTransactions())
                .reasonSummary(result.getReasonSummary())
                .build();
    }

    private boolean matchesBenefit(NormalizedTransaction tx, CardBenefitRule benefit) {
        String txCategory = categoryNormalizer.normalize(tx.getCategory());
        String ruleCategory = categoryNormalizer.normalize(benefit.getCategory());
        String ruleMerchant = normalizeMerchantKey(benefit.getMerchantName());

        if (!ruleMerchant.isBlank()) {
            return isMerchantStrongMatch(tx.getMerchant(), benefit.getMerchantName());
        }

        return ruleCategory.equals("ETC") || txCategory.equals(ruleCategory);
    }

    private boolean matchesPromotion(NormalizedTransaction tx, CardPromotionRule promo) {
        String txCategory = categoryNormalizer.normalize(tx.getCategory());
        String promoCategory = categoryNormalizer.normalize(promo.getCategory());
        String promoMerchant = normalizeMerchantKey(promo.getMerchantName());

        if (!promoMerchant.isBlank()) {
            return isMerchantStrongMatch(tx.getMerchant(), promo.getMerchantName());
        }

        return !promoCategory.equals("ETC") && txCategory.equals(promoCategory);
    }

    private boolean isMerchantStrongMatch(String txMerchantRaw, String ruleMerchantRaw) {
        String txMerchant = normalizeMerchantKey(txMerchantRaw);
        String ruleMerchant = normalizeMerchantKey(ruleMerchantRaw);

        if (txMerchant.isBlank() || ruleMerchant.isBlank()) return false;
        if (txMerchant.equals(ruleMerchant)) return true;
        if (txMerchant.contains(ruleMerchant) || ruleMerchant.contains(txMerchant)) return true;

        String txAnchor = extractMerchantAnchor(txMerchant);
        String ruleAnchor = extractMerchantAnchor(ruleMerchant);

        if (!txAnchor.isBlank() && !ruleAnchor.isBlank() && txAnchor.equals(ruleAnchor)) {
            return true;
        }

        List<String> txTokens = meaningfulMerchantTokens(txMerchant);
        List<String> ruleTokens = meaningfulMerchantTokens(ruleMerchant);

        if (txTokens.isEmpty() || ruleTokens.isEmpty()) return false;

        Set<String> txSet = new LinkedHashSet<>(txTokens);
        Set<String> ruleSet = new LinkedHashSet<>(ruleTokens);

        if (txSet.equals(ruleSet)) return true;

        if (ruleSet.size() == 1) {
            return txSet.contains(ruleTokens.get(0));
        }

        int matched = 0;
        for (String token : ruleSet) {
            if (txSet.contains(token)) {
                matched++;
            }
        }

        return matched == ruleSet.size();
    }

    private String extractMerchantAnchor(String merchant) {
        List<String> tokens = meaningfulMerchantTokens(merchant);
        if (tokens.isEmpty()) return "";

        String joined = String.join(" ", tokens);

        List<String> anchors = List.of(
                "스타벅스", "투썸플레이스", "이디야", "메가커피", "빽다방", "공차",
                "맥도날드", "롯데리아", "버거킹", "kfc", "서브웨이", "써브웨이", "아웃백",
                "올리브영", "이니스프리", "무신사", "다이소", "아트박스", "영풍문고",
                "이마트", "롯데마트", "홈플러스", "쿠팡",
                "cu", "gs25", "세븐일레븐", "이마트24",
                "sk에너지", "s oil", "s-oil", "gs칼텍스", "현대오일뱅크",
                "대한항공", "아시아나", "ktx",
                "포토이즘", "인생네컷", "와플대학", "커피에반하다"
        );

        for (String anchor : anchors) {
            String normalizedAnchor = normalizeMerchantKey(anchor);
            if (!normalizedAnchor.isBlank() && joined.contains(normalizedAnchor)) {
                return normalizedAnchor;
            }
        }

        return tokens.get(0);
    }

    private List<String> meaningfulMerchantTokens(String merchant) {
        if (merchant == null || merchant.isBlank()) return Collections.emptyList();

        String normalized = normalizeMerchantKey(merchant);
        if (normalized.isBlank()) return Collections.emptyList();

        String[] rawTokens = normalized.split(" ");
        List<String> result = new ArrayList<>();

        for (String token : rawTokens) {
            if (token.isBlank()) continue;
            if (GENERIC_MERCHANT_TOKENS.contains(token)) continue;
            if (token.length() == 1) continue;
            result.add(token);
        }

        return result;
    }

    private String normalizeMerchantKey(String merchant) {
        if (merchant == null) return "";

        return merchantNormalizer.normalize(merchant)
                .toLowerCase()
                .replace("주식회사", " ")
                .replace("(주)", " ")
                .replace("㈜", " ")
                .replace("co ltd", " ")
                .replace("co., ltd", " ")
                .replace("ltd", " ")
                .replaceAll("[^가-힣a-z0-9 ]", " ")
                .replaceAll("\\s+", " ")
                .trim();
    }

    private boolean isPromotionApplicable(RecommendationCardProfile card, CardPromotionRule promo) {
        String targetCardName = promo.getTargetCardName();
        if (targetCardName == null || targetCardName.isBlank()) return false;

        if ("All".equalsIgnoreCase(targetCardName.trim())) return true;

        String normalizedCard = normalizeCardName(card.getCardName());
        String[] targets = targetCardName.split(",");

        for (String target : targets) {
            String normalizedTarget = normalizeCardName(target);
            if (!normalizedTarget.isBlank() && normalizedTarget.equals(normalizedCard)) {
                return true;
            }
        }

        return false;
    }

    private String normalizeCardName(String cardName) {
        if (cardName == null) return "";
        return cardName.replaceAll("\\s+", "").trim().toLowerCase();
    }

    private boolean isPromotionPeriodValid(CardPromotionRule promo) {
        LocalDate today = LocalDate.now();

        if (!promo.isActive()) return false;
        if (promo.getStartDate() != null && today.isBefore(promo.getStartDate())) return false;
        if (promo.getEndDate() != null && today.isAfter(promo.getEndDate())) return false;

        return true;
    }

    private boolean isPreviousMonthSpendEligible(BigDecimal previousMonthSpend, Double min, Double max) {
        if (min != null && previousMonthSpend.compareTo(BigDecimal.valueOf(min)) < 0) return false;
        if (max != null && previousMonthSpend.compareTo(BigDecimal.valueOf(max)) > 0) return false;
        return true;
    }

    private boolean isMinAmountSatisfied(BigDecimal amount, Double minAmount) {
        if (minAmount == null) return true;
        return amount.compareTo(BigDecimal.valueOf(minAmount)) >= 0;
    }

    private boolean isCountAvailable(Integer maxCount, Integer currentCount) {
        if (maxCount == null) return true;
        int used = currentCount == null ? 0 : currentCount;
        return used < maxCount;
    }

    private boolean matchesChannel(String txChannel, String eligibleChannels) {
        if (eligibleChannels == null || eligibleChannels.isBlank()) return true;
        if (txChannel == null || txChannel.isBlank()) return true;

        String normalizedTxChannel = txChannel.trim().toUpperCase();
        String[] allowed = eligibleChannels.split(",");

        for (String channel : allowed) {
            if (normalizedTxChannel.equals(channel.trim().toUpperCase())) {
                return true;
            }
        }
        return false;
    }

    private BigDecimal applyPerTransactionMax(BigDecimal amount, Double maxAmount) {
        if (maxAmount == null) return amount;
        return amount.min(BigDecimal.valueOf(maxAmount));
    }

    private BigDecimal applyMonthlyLimit(BigDecimal saving, Double monthlyLimit, BigDecimal usedSoFar) {
        if (monthlyLimit == null) return saving;

        BigDecimal limit = BigDecimal.valueOf(monthlyLimit);
        BigDecimal used = usedSoFar == null ? BigDecimal.ZERO : usedSoFar;
        BigDecimal remaining = limit.subtract(used);

        if (remaining.compareTo(BigDecimal.ZERO) <= 0) return BigDecimal.ZERO;
        return saving.min(remaining);
    }

    private BigDecimal applyAbsoluteCap(BigDecimal saving, Double maxBenefitAmount) {
        if (maxBenefitAmount == null) return saving;
        return saving.min(BigDecimal.valueOf(maxBenefitAmount));
    }

    private BigDecimal calculateSaving(BigDecimal amount, String benefitType, double benefitValue) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }

        BigDecimal value = BigDecimal.valueOf(benefitValue);

        if ("RATE".equalsIgnoreCase(benefitType)) {
            return amount.multiply(value)
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        }

        if ("AMOUNT".equalsIgnoreCase(benefitType) || "POINT".equalsIgnoreCase(benefitType)) {
            return value.max(BigDecimal.ZERO);
        }

        if ("FREE".equalsIgnoreCase(benefitType)) {
            return BigDecimal.ZERO;
        }

        return BigDecimal.ZERO;
    }

    private int buildScore(
            long estimatedSaving,
            int coveragePercent,
            List<String> matchedCategories,
            List<String> topCategories,
            int promotionMatchedCount
    ) {
        int savingScore = (int) Math.min(estimatedSaving / 120, 180);
        int coverageScore = Math.min(coveragePercent, 35);

        int topCategoryBonus = 0;
        for (String topCategory : topCategories) {
            if (matchedCategories.contains(topCategory)) {
                topCategoryBonus += 12;
            }
        }

        int promotionBonus = Math.min(promotionMatchedCount * 2, 20);

        return savingScore + coverageScore + topCategoryBonus + promotionBonus;
    }

    private String buildReasonSummary(
            List<String> matchedCategories,
            long estimatedSaving,
            int matchedTransactionCount,
            int totalTransactionCount,
            int promotionMatchedCount
    ) {
        String categories = matchedCategories.isEmpty()
                ? "일부"
                : String.join(", ", matchedCategories);

        String promoText = promotionMatchedCount > 0
                ? " 프로모션 적용 건수는 " + promotionMatchedCount + "건입니다."
                : "";

        return categories + " 소비에서 혜택이 발생했고, 이번 달 "
                + totalTransactionCount + "건 중 "
                + matchedTransactionCount + "건에 적용되어 예상 "
                + estimatedSaving + "원 절약이 가능합니다."
                + promoText;
    }

    private List<String> reorderByTopCategories(List<String> matchedCategories, List<String> topCategories) {
        return matchedCategories.stream()
                .sorted(Comparator.comparingInt(category -> {
                    int idx = topCategories.indexOf(category);
                    return idx >= 0 ? idx : 999;
                }))
                .toList();
    }

    private List<NormalizedTransaction> normalizeTransactions(List<Map<String, Object>> rawTransactions) {
        List<NormalizedTransaction> result = new ArrayList<>();

        for (Map<String, Object> tx : rawTransactions) {
            String rawType = str(tx.get("transactionType"));
            if (rawType.isBlank()) rawType = str(tx.get("transaction_type"));
            if (rawType.isBlank()) rawType = str(tx.get("type"));

            String rawCategory = str(tx.get("category"));
            if (rawCategory.isBlank()) rawCategory = str(tx.get("categoryCode"));
            if (rawCategory.isBlank()) rawCategory = str(tx.get("category_code"));

            String rawMerchant = str(tx.get("description"));
            if (rawMerchant.isBlank()) rawMerchant = str(tx.get("merchantName"));
            if (rawMerchant.isBlank()) rawMerchant = str(tx.get("merchant_name"));
            if (rawMerchant.isBlank()) rawMerchant = str(tx.get("toAccount"));
            if (rawMerchant.isBlank()) rawMerchant = str(tx.get("to_account"));

            String rawChannel = str(tx.get("channel"));
            if (rawChannel.isBlank()) rawChannel = str(tx.get("transactionChannel"));
            if (rawChannel.isBlank()) rawChannel = str(tx.get("transaction_channel"));

            BigDecimal amount = toBigDecimal(tx.get("amount"));

            LocalDateTime createdAt = parseDate(tx.get("createdAt"));
            if (createdAt == null) createdAt = parseDate(tx.get("created_at"));
            if (createdAt == null) createdAt = parseDate(tx.get("date"));

            boolean isExpense = isExpense(rawType);

            result.add(NormalizedTransaction.builder()
                    .category(categoryNormalizer.normalize(rawCategory))
                    .merchant(merchantNormalizer.normalize(rawMerchant))
                    .amount(amount)
                    .createdAt(createdAt)
                    .expense(isExpense)
                    .channel(normalizeChannel(rawChannel))
                    .build());
        }

        return result;
    }

    private List<NormalizedTransaction> filterCurrentMonthExpenses(List<NormalizedTransaction> transactions) {
        YearMonth currentMonth = YearMonth.now();

        return transactions.stream()
                .filter(NormalizedTransaction::isExpense)
                .filter(tx -> tx.getAmount() != null && tx.getAmount().compareTo(BigDecimal.ZERO) > 0)
                .filter(tx -> tx.getCreatedAt() != null)
                .filter(tx -> YearMonth.from(tx.getCreatedAt()).equals(currentMonth))
                .toList();
    }

    private BigDecimal calculatePreviousMonthSpend(List<NormalizedTransaction> transactions) {
        YearMonth previousMonth = YearMonth.now().minusMonths(1);

        return transactions.stream()
                .filter(NormalizedTransaction::isExpense)
                .filter(tx -> tx.getAmount() != null && tx.getAmount().compareTo(BigDecimal.ZERO) > 0)
                .filter(tx -> tx.getCreatedAt() != null)
                .filter(tx -> YearMonth.from(tx.getCreatedAt()).equals(previousMonth))
                .map(NormalizedTransaction::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private Map<String, BigDecimal> aggregateSpendingByCategory(List<NormalizedTransaction> transactions) {
        Map<String, BigDecimal> map = new HashMap<>();

        for (NormalizedTransaction tx : transactions) {
            map.put(
                    tx.getCategory(),
                    map.getOrDefault(tx.getCategory(), BigDecimal.ZERO).add(tx.getAmount())
            );
        }

        return map.entrySet().stream()
                .sorted(Map.Entry.<String, BigDecimal>comparingByValue().reversed())
                .collect(Collectors.toMap(
                        Map.Entry::getKey,
                        Map.Entry::getValue,
                        (a, b) -> a,
                        LinkedHashMap::new
                ));
    }

    private boolean isExpense(String rawType) {
        String type = rawType == null ? "" : rawType.trim().toUpperCase();
        return !(type.equals("DEPOSIT")
                || type.equals("IN")
                || type.equals("INCOME")
                || type.equals("CREDIT")
                || type.equals("입금"));
    }

    private String normalizeChannel(String rawChannel) {
        if (rawChannel == null || rawChannel.isBlank()) return "UNKNOWN";
        String value = rawChannel.trim().toUpperCase();
        if (value.equals("APP")) return "APP";
        if (value.equals("ONLINE") || value.equals("WEB")) return "ONLINE";
        if (value.equals("OFFLINE") || value.equals("STORE")) return "OFFLINE";
        return value;
    }

    private LocalDateTime parseDate(Object value) {
        if (value == null) return null;

        String text = String.valueOf(value).trim();
        if (text.isBlank()) return null;

        for (DateTimeFormatter formatter : DATE_FORMATTERS) {
            try {
                return LocalDateTime.parse(text, formatter);
            } catch (DateTimeParseException ignored) {
            }
        }

        try {
            return LocalDateTime.parse(text.replace(" ", "T"));
        } catch (Exception ignored) {
        }

        return null;
    }

    private BigDecimal toBigDecimal(Object value) {
        if (value == null) return BigDecimal.ZERO;
        try {
            return new BigDecimal(String.valueOf(value).replace(",", "").trim());
        } catch (Exception e) {
            return BigDecimal.ZERO;
        }
    }

    private long toLongWon(BigDecimal value) {
        if (value == null) return 0L;
        return value.setScale(0, RoundingMode.HALF_UP).longValue();
    }

    private String str(Object value) {
        return value == null ? "" : String.valueOf(value);
    }

    private String defaultString(String value, String defaultValue) {
        return (value == null || value.isBlank()) ? defaultValue : value;
    }

    private <T> List<T> safeList(List<T> values) {
        return values == null ? Collections.emptyList() : values;
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> castListMap(Object value) {
        if (value == null) return Collections.emptyList();
        return (List<Map<String, Object>>) value;
    }

    private record BenefitApplied(
            boolean applied,
            CardBenefitRule rule,
            String ruleKey,
            BigDecimal saving
    ) {
        static BenefitApplied notApplied(CardBenefitRule rule, String ruleKey) {
            return new BenefitApplied(false, rule, ruleKey, BigDecimal.ZERO);
        }
    }

    private record PromotionApplied(
            boolean applied,
            CardPromotionRule rule,
            String ruleKey,
            BigDecimal saving
    ) {
        static PromotionApplied notApplied(CardPromotionRule rule, String ruleKey) {
            return new PromotionApplied(false, rule, ruleKey, BigDecimal.ZERO);
        }
    }
}
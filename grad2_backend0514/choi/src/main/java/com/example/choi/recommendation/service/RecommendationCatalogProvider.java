// service/RecommendationCatalogProvider.java
package com.example.choi.recommendation.service;

import com.example.choi.recommendation.dto.CardBenefitRule;
import com.example.choi.recommendation.dto.CardPromotionRule;
import com.example.choi.recommendation.dto.RecommendationCardProfile;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Objects;

@Component
public class RecommendationCatalogProvider {

    private final WebClient webClient;
    private final CategoryNormalizer categoryNormalizer;

    @Value("${bank.api.hana.base-url:http://localhost:8001}")
    private String hanaBaseUrl;

    @Value("${bank.api.kukmin.base-url:http://localhost:8002}")
    private String kukminBaseUrl;

    @Value("${bank.api.noori.base-url:http://localhost:8003}")
    private String nooriBaseUrl;

    public RecommendationCatalogProvider(WebClient.Builder webClientBuilder,
                                         CategoryNormalizer categoryNormalizer) {
        this.webClient = webClientBuilder.build();
        this.categoryNormalizer = categoryNormalizer;
    }

    /**
     * 세 은행 카탈로그를 모두 비동기로 호출해서 하나의 List로 합친다.
     */
    public Mono<List<RecommendationCardProfile>> getAllCards() {
        Mono<List<RecommendationCardProfile>> hana = fetchBankCards(hanaBaseUrl, "hana");
        Mono<List<RecommendationCardProfile>> kukmin = fetchBankCards(kukminBaseUrl, "kukmin");
        Mono<List<RecommendationCardProfile>> noori = fetchBankCards(nooriBaseUrl, "noori");

        return Mono.zip(hana, kukmin, noori)
                .map(tuple -> {
                    List<RecommendationCardProfile> result = new ArrayList<>();
                    result.addAll(tuple.getT1());
                    result.addAll(tuple.getT2());
                    result.addAll(tuple.getT3());
                    return result;
                });
    }

    /**
     * 은행 하나의 /api/v1/catalog/cards 를 호출해서 카드 리스트로 변환.
     */
    private Mono<List<RecommendationCardProfile>> fetchBankCards(String baseUrl, String defaultBankName) {
        return webClient.get()
                .uri(baseUrl + "/api/v1/catalog/cards")
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
                .map(response -> {
                    if (response == null) return Collections.<RecommendationCardProfile>emptyList();

                    Object cardsObj = response.get("cards");
                    if (!(cardsObj instanceof List<?> rawCards)) {
                        return Collections.<RecommendationCardProfile>emptyList();
                    }

                    List<RecommendationCardProfile> result = new ArrayList<>();
                    for (Object rawCard : rawCards) {
                        if (!(rawCard instanceof Map<?, ?> rawMap)) continue;

                        @SuppressWarnings("unchecked")
                        Map<String, Object> cardMap = (Map<String, Object>) rawMap;

                        RecommendationCardProfile profile = mapCardProfile(cardMap, defaultBankName);
                        if (profile != null) {
                            result.add(profile);
                        }
                    }
                    return result;
                })
                .onErrorResume(e -> {
                    System.err.println("[RecommendationCatalogProvider] failed to fetch cards from "
                            + defaultBankName + " (" + baseUrl + "): " + e.getMessage());
                    return Mono.just(Collections.emptyList());
                });
    }

    private RecommendationCardProfile mapCardProfile(Map<String, Object> cardMap, String defaultBankName) {
        String cardId = stringValue(firstNonNull(cardMap.get("card_id"), cardMap.get("cardId")));
        String cardName = stringValue(firstNonNull(cardMap.get("card_name"), cardMap.get("cardName")));
        String bankName = stringValue(firstNonNull(cardMap.get("bank_code"), cardMap.get("bankName")));
        String cardType = stringValue(firstNonNull(cardMap.get("card_type"), cardMap.get("cardType")));

        if (bankName.isBlank()) bankName = defaultBankName;
        if (cardId.isBlank() || cardName.isBlank()) return null;

        return RecommendationCardProfile.builder()
                .cardId(cardId)
                .cardName(cardName)
                .bankName(bankName)
                .cardType(normalizeCardType(cardType))
                .benefits(mapBenefits(cardMap.get("card_benefits"), cardMap.get("benefits")))
                .promotions(mapPromotions(cardMap.get("promotions")))
                .build();
    }

    private List<CardBenefitRule> mapBenefits(Object cardBenefitsObj, Object fallbackBenefitsObj) {
        List<CardBenefitRule> result = new ArrayList<>();

        if (cardBenefitsObj instanceof List<?> rawBenefits) {
            for (Object rawBenefit : rawBenefits) {
                if (!(rawBenefit instanceof Map<?, ?> benefitRaw)) continue;

                @SuppressWarnings("unchecked")
                Map<String, Object> benefitMap = (Map<String, Object>) benefitRaw;

                result.add(CardBenefitRule.builder()
                        .category(normalizeCategory(stringValue(firstNonNull(
                                benefitMap.get("category_code"),
                                benefitMap.get("categoryCode"),
                                benefitMap.get("category")
                        ))))
                        .merchantName(stringValue(firstNonNull(
                                benefitMap.get("merchant_name"),
                                benefitMap.get("merchantName")
                        )))
                        .benefitType(normalizeBenefitType(stringValue(firstNonNull(
                                benefitMap.get("benefit_type"),
                                benefitMap.get("benefitType")
                        ))))
                        .benefitValue(doubleValue(firstNonNull(
                                benefitMap.get("benefit_value"),
                                benefitMap.get("benefitValue")
                        )))
                        .unit(normalizeUnit(stringValue(firstNonNull(
                                benefitMap.get("benefit_unit"),
                                benefitMap.get("benefitUnit")
                        ))))
                        .description(stringValue(firstNonNull(
                                benefitMap.get("description"),
                                benefitMap.get("title")
                        )))
                        .active(booleanValue(firstNonNull(
                                benefitMap.get("is_active"),
                                benefitMap.get("active"),
                                true
                        )))
                        .previousMonthSpendMin(nullableDouble(firstNonNull(
                                benefitMap.get("previous_month_spend_min"),
                                benefitMap.get("previousMonthSpendMin")
                        )))
                        .previousMonthSpendMax(nullableDouble(firstNonNull(
                                benefitMap.get("previous_month_spend_max"),
                                benefitMap.get("previousMonthSpendMax")
                        )))
                        .monthlyBenefitLimit(nullableDouble(firstNonNull(
                                benefitMap.get("monthly_benefit_limit"),
                                benefitMap.get("monthlyBenefitLimit")
                        )))
                        .maxBenefitCountPerMonth(nullableInteger(firstNonNull(
                                benefitMap.get("max_benefit_count_per_month"),
                                benefitMap.get("maxBenefitCountPerMonth")
                        )))
                        .perTransactionMinAmount(nullableDouble(firstNonNull(
                                benefitMap.get("per_transaction_min_amount"),
                                benefitMap.get("perTransactionMinAmount")
                        )))
                        .perTransactionMaxAmount(nullableDouble(firstNonNull(
                                benefitMap.get("per_transaction_max_amount"),
                                benefitMap.get("perTransactionMaxAmount")
                        )))
                        .eligibleChannels(stringValue(firstNonNull(
                                benefitMap.get("eligible_channels"),
                                benefitMap.get("eligibleChannels")
                        )))
                        .build());
            }
            return result;
        }

        if (fallbackBenefitsObj instanceof Map<?, ?> benefitMapRaw) {
            @SuppressWarnings("unchecked")
            Map<String, Object> benefitMap = (Map<String, Object>) benefitMapRaw;

            for (Map.Entry<String, Object> entry : benefitMap.entrySet()) {
                String category = normalizeCategory(entry.getKey());
                String description = stringValue(entry.getValue());

                result.add(CardBenefitRule.builder()
                        .category(category)
                        .merchantName("")
                        .benefitType(inferBenefitType(description))
                        .benefitValue(extractNumericValue(description))
                        .unit(inferUnit(description))
                        .description(description)
                        .active(true)
                        .build());
            }
        }

        return result;
    }

    private List<CardPromotionRule> mapPromotions(Object promotionsObj) {
        if (!(promotionsObj instanceof List<?> rawPromotions)) {
            return Collections.emptyList();
        }

        List<CardPromotionRule> result = new ArrayList<>();

        for (Object rawPromo : rawPromotions) {
            if (!(rawPromo instanceof Map<?, ?> promoRaw)) continue;

            @SuppressWarnings("unchecked")
            Map<String, Object> promoMap = (Map<String, Object>) promoRaw;

            result.add(CardPromotionRule.builder()
                    .title(stringValue(promoMap.get("title")))
                    .description(stringValue(firstNonNull(
                            promoMap.get("content"),
                            promoMap.get("description")
                    )))
                    .startDate(parseLocalDate(firstNonNull(
                            promoMap.get("start_date"),
                            promoMap.get("startDate")
                    )))
                    .endDate(parseLocalDate(firstNonNull(
                            promoMap.get("end_date"),
                            promoMap.get("endDate")
                    )))
                    .active(booleanValue(firstNonNull(
                            promoMap.get("is_active"),
                            promoMap.get("active"),
                            true
                    )))
                    .category(normalizeCategory(stringValue(firstNonNull(
                            promoMap.get("category_code"),
                            promoMap.get("category")
                    ))))
                    .merchantName(stringValue(firstNonNull(
                            promoMap.get("merchant_name"),
                            promoMap.get("merchantName")
                    )))
                    .benefitType(normalizeBenefitType(stringValue(firstNonNull(
                            promoMap.get("benefit_type"),
                            promoMap.get("benefitType")
                    ))))
                    .benefitValue(doubleValue(firstNonNull(
                            promoMap.get("benefit_value"),
                            promoMap.get("benefitValue")
                    )))
                    .targetCardName(stringValue(firstNonNull(
                            promoMap.get("target_cards"),
                            promoMap.get("targetCardName")
                    )))
                    .promotionMinAmount(nullableDouble(firstNonNull(
                            promoMap.get("promotion_min_amount"),
                            promoMap.get("promotionMinAmount")
                    )))
                    .promotionMaxBenefitAmount(nullableDouble(firstNonNull(
                            promoMap.get("promotion_max_benefit_amount"),
                            promoMap.get("promotionMaxBenefitAmount")
                    )))
                    .promotionMaxCount(nullableInteger(firstNonNull(
                            promoMap.get("promotion_max_count"),
                            promoMap.get("promotionMaxCount")
                    )))
                    .promotionChannel(stringValue(firstNonNull(
                            promoMap.get("promotion_channel"),
                            promoMap.get("promotionChannel")
                    )))
                    .stackableWithBaseBenefit(nullableBoolean(firstNonNull(
                            promoMap.get("stackable_with_base_benefit"),
                            promoMap.get("stackableWithBaseBenefit")
                    )))
                    .build());
        }

        return result;
    }

    private String normalizeCategory(String rawCategory) {
        return categoryNormalizer.normalize(rawCategory);
    }

    private String normalizeCardType(String rawCardType) {
        if (rawCardType == null || rawCardType.isBlank()) return "Unknown";
        String value = rawCardType.trim().toUpperCase();
        if (value.equals("CREDIT") || value.equals("신용")) return "Credit";
        if (value.equals("CHECK") || value.equals("DEBIT") || value.equals("체크")) return "Check";
        return rawCardType;
    }

    private String normalizeBenefitType(String rawBenefitType) {
        if (rawBenefitType == null || rawBenefitType.isBlank()) return "AMOUNT";
        String value = rawBenefitType.trim().toUpperCase();
        if (value.equals("RATE") || value.equals("PERCENT")) return "RATE";
        if (value.equals("AMOUNT") || value.equals("WON")) return "AMOUNT";
        if (value.equals("POINT")) return "POINT";
        if (value.equals("FREE")) return "FREE";
        return value;
    }

    private String normalizeUnit(String rawUnit) {
        if (rawUnit == null || rawUnit.isBlank()) return "UNKNOWN";
        String value = rawUnit.trim().toUpperCase();
        if (value.equals("%") || value.equals("PERCENT")) return "PERCENT";
        if (value.equals("원") || value.equals("WON")) return "WON";
        if (value.equals("POINT") || value.equals("P")) return "POINT";
        if (value.equals("FREE")) return "FREE";
        return value;
    }

    private String inferBenefitType(String description) {
        String text = stringValue(description);
        if (text.contains("%")) return "RATE";
        if (text.contains("적립") && !text.contains("%")) return "POINT";
        if (text.contains("무료")) return "FREE";
        return "AMOUNT";
    }

    private String inferUnit(String description) {
        String text = stringValue(description);
        if (text.contains("%")) return "PERCENT";
        if (text.contains("적립")) return "POINT";
        if (text.contains("무료")) return "FREE";
        return "WON";
    }

    private double extractNumericValue(String description) {
        String text = stringValue(description).replaceAll(",", "");
        String onlyNumber = text.replaceAll("[^0-9.]", "");
        if (onlyNumber.isBlank()) return 0.0;
        try {
            return Double.parseDouble(onlyNumber);
        } catch (Exception e) {
            return 0.0;
        }
    }

    private LocalDate parseLocalDate(Object value) {
        if (value == null) return null;
        String text = String.valueOf(value).trim();
        if (text.isBlank()) return null;
        try {
            return text.length() >= 10 ? LocalDate.parse(text.substring(0, 10)) : LocalDate.parse(text);
        } catch (DateTimeParseException e) {
            return null;
        }
    }

    private String stringValue(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }

    private double doubleValue(Object value) {
        if (value == null) return 0.0;
        try {
            return Double.parseDouble(String.valueOf(value).replace(",", "").trim());
        } catch (Exception e) {
            return 0.0;
        }
    }

    private Double nullableDouble(Object value) {
        if (value == null) return null;
        try {
            return Double.parseDouble(String.valueOf(value).replace(",", "").trim());
        } catch (Exception e) {
            return null;
        }
    }

    private Integer nullableInteger(Object value) {
        if (value == null) return null;
        try {
            return Integer.parseInt(String.valueOf(value).replace(",", "").trim());
        } catch (Exception e) {
            return null;
        }
    }

    private Boolean nullableBoolean(Object value) {
        if (value == null) return null;
        if (value instanceof Boolean b) return b;
        String text = String.valueOf(value).trim().toLowerCase();
        if (text.equals("true") || text.equals("1") || text.equals("y") || text.equals("yes")) return true;
        if (text.equals("false") || text.equals("0") || text.equals("n") || text.equals("no")) return false;
        return null;
    }

    private boolean booleanValue(Object value) {
        return Boolean.TRUE.equals(nullableBoolean(value));
    }

    private Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (Objects.nonNull(value)) return value;
        }
        return null;
    }
}
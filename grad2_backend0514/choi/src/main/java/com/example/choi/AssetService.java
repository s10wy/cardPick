// AssetService.java
package com.example.choi;

import com.example.choi.entity.Card;
import com.example.choi.entity.User;
import com.example.choi.repo.CardRepo;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AssetService {

    private final JwtUtil jwtUtil;
    private final UserService userService;
    private final CardRepo cardRepo;

    @Value("${app.demo.user-email}")
    private String demoUserEmail;

    private final WebClient webClient = WebClient.builder().build();

    private final Map<String, String> BANK_URLS = Map.of(
            "하나은행", "http://127.0.0.1:8001/user/assets",
            "국민은행", "http://127.0.0.1:8002/user/assets",
            "누리은행", "http://127.0.0.1:8003/user/assets"
    );

    public Mono<Map<String, Object>> getIntegratedAssets(String userEmail, String token) {
        System.out.println("검증 요청 이메일: " + userEmail);
        System.out.println("조회용 demo 이메일: " + demoUserEmail);

        if (token != null && !token.isBlank()) {
            if (!jwtUtil.validateToken(token, userEmail)) {
                return Mono.error(new SecurityException("인증되지 않은 사용자의 접근입니다."));
            }
        }

        User demoUser = userService.getUserByEmail(demoUserEmail);
        List<Card> myRegisteredCards = cardRepo.findByUser_UserId(demoUser.getUserId());

        List<Mono<Map<String, Object>>> tasks = BANK_URLS.entrySet().stream()
                .map(entry -> fetchBankData(entry.getKey(), entry.getValue(), demoUserEmail))
                .collect(Collectors.toList());

        return Mono.zip(tasks, responses -> {
            long totalBalance = 0L;
            List<Map<String, Object>> allAccounts = new ArrayList<>();
            List<Map<String, Object>> allTransactions = new ArrayList<>();
            List<Map<String, Object>> bankCards = new ArrayList<>();

            for (Object obj : responses) {
                Map<String, Object> res = (Map<String, Object>) obj;
                String bankName = (String) res.getOrDefault("bank", "알 수 없는 은행");

                List<Map<String, Object>> accounts =
                        (List<Map<String, Object>>) res.getOrDefault("accounts", Collections.emptyList());
                for (Map<String, Object> acc : accounts) {
                    totalBalance += ((Number) acc.getOrDefault("balance", 0)).longValue();
                    acc.put("bankOrigin", bankName);
                    allAccounts.add(acc);
                }

                List<Map<String, Object>> cards =
                        (List<Map<String, Object>>) res.getOrDefault("my_cards", Collections.emptyList());
                for (Map<String, Object> card : cards) {
                    card.put("bankOrigin", bankName);
                }
                bankCards.addAll(cards);

                List<Map<String, Object>> transactions =
                        (List<Map<String, Object>>) res.getOrDefault("transactions", Collections.emptyList());
                for (Map<String, Object> tx : transactions) {
                    tx.put("bankOrigin", bankName);

                    if (tx.containsKey("created_at") && !tx.containsKey("createdAt")) {
                        tx.put("createdAt", tx.get("created_at"));
                    }
                    if (tx.containsKey("transaction_type") && !tx.containsKey("transactionType")) {
                        tx.put("transactionType", tx.get("transaction_type"));
                    }
                    if (tx.containsKey("from_account") && !tx.containsKey("fromAccount")) {
                        tx.put("fromAccount", tx.get("from_account"));
                    }
                    if (tx.containsKey("to_account") && !tx.containsKey("toAccount")) {
                        tx.put("toAccount", tx.get("to_account"));
                    }

                    allTransactions.add(tx);
                }
            }

            Map<String, Object> result = new HashMap<>();
            result.put("username", demoUser.getUsername());
            result.put("totalbalance", totalBalance);
            result.put("accounts", allAccounts);
            result.put("transactions", allTransactions);
            result.put("myregisteredcards", myRegisteredCards);
            result.put("availablebankcards", bankCards);

            return result;
        });
    }

    private Mono<Map<String, Object>> fetchBankData(String bankName, String url, String email) {
        return webClient.get()
                .uri(url + "/" + email)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
                .map(body -> {
                    Map<String, Object> result = new HashMap<>(body);
                    result.put("bank", bankName);
                    return result;
                })
                .onErrorResume(e -> {
                    System.out.println(bankName + " API 호출 실패: " + e.getMessage());
                    return Mono.just(new HashMap<>(Map.of(
                            "bank", bankName,
                            "status", "error",
                            "accounts", Collections.emptyList(),
                            "my_cards", Collections.emptyList(),
                            "transactions", Collections.emptyList()
                    )));
                });
    }
}
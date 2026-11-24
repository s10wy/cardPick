// TransactionController.java
package com.example.choi;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class TransactionController {

    private final JwtUtil jwtUtil;
    private final AssetService assetService;

    @GetMapping("/transactions/current-month/{userEmail}")
    public Mono<ResponseEntity<List<Map<String, Object>>>> getCurrentMonthTransactions(
            @PathVariable String userEmail,
            @RequestHeader(value = "Authorization", required = false) String bearerToken
    ) {
        String token = null;

        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            token = bearerToken.substring(7);
        }

        if (token != null && !token.isBlank() && !jwtUtil.validateToken(token, userEmail)) {
            return Mono.just(ResponseEntity.status(401).build());
        }

        ZonedDateTime startOfMonth = ZonedDateTime.now()
                .with(TemporalAdjusters.firstDayOfMonth())
                .toLocalDate()
                .atStartOfDay(ZonedDateTime.now().getZone());

        return assetService.getIntegratedAssets(userEmail, token)
                .map(data -> {
                    List<Map<String, Object>> txs =
                            (List<Map<String, Object>>) data.getOrDefault("transactions", Collections.emptyList());

                    List<Map<String, Object>> filtered = txs.stream()
                            .filter(tx -> {
                                Object createdAtObj = tx.get("createdAt");
                                if (createdAtObj == null) {
                                    createdAtObj = tx.get("created_at");
                                }
                                if (createdAtObj == null) return false;

                                try {
                                    ZonedDateTime createdAt = ZonedDateTime.parse(createdAtObj.toString());
                                    return !createdAt.isBefore(startOfMonth);
                                } catch (Exception e) {
                                    return true;
                                }
                            })
                            .collect(Collectors.toList());

                    return ResponseEntity.ok(filtered);
                })
                .onErrorResume(e -> {
                    e.printStackTrace();
                    return Mono.just(ResponseEntity.status(500).build());
                });
    }
}
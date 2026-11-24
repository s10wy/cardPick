//controller/CardRecommendationController.java
package com.example.choi.recommendation.controller;

import com.example.choi.JwtUtil;
import com.example.choi.recommendation.dto.RecommendedCardResponse;
import com.example.choi.recommendation.service.CardRecommendationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
@RequestMapping("/cards")
public class CardRecommendationController {

    private final JwtUtil jwtUtil;
    private final CardRecommendationService cardRecommendationService;

    @GetMapping("/recommendation/{userEmail}")
    public Mono<ResponseEntity<RecommendedCardResponse>> recommendCards(
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

        return cardRecommendationService.recommendCards(userEmail, token)
                .map(ResponseEntity::ok)
                .onErrorResume(e -> {
                    e.printStackTrace();
                    return Mono.just(ResponseEntity.status(500).build());
                });
    }
}
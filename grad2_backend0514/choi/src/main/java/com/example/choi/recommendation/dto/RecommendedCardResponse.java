//dto/RecommendedCardResponse.java
package com.example.choi.recommendation.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecommendedCardResponse {
    private String userEmail;
    private String analyzedMonth;
    private List<String> topCategories;
    private List<RecommendedCardItem> recommendedCards;
}
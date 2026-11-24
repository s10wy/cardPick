//dto/CardPromotionRule.java
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
public class RecommendationCardProfile {
    private String cardId;
    private String cardName;
    private String bankName;
    private String cardType;
    private List<CardBenefitRule> benefits;
    private List<CardPromotionRule> promotions;
}
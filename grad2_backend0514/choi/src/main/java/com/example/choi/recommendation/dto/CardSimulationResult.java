//dto/CardSimulationResult.java
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
public class CardSimulationResult {
    private RecommendationCardProfile cardProfile;
    private Long estimatedSaving;
    private Integer score;
    private Integer matchedTransactionCount;
    private Integer totalTransactionCount;
    private Integer benefitCoveragePercent;
    private List<String> matchedCategories;
    private List<String> benefitDetails;
    private List<String> appliedPromotions;
    private List<TransactionBenefitDetail> topSavingTransactions;
    private String reasonSummary;
}
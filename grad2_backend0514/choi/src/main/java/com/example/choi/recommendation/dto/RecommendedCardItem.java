//dto/RecommendedCardItem.java
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
public class RecommendedCardItem {
    private String cardId;
    private String cardName;
    private String bankName;
    private String cardType;
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
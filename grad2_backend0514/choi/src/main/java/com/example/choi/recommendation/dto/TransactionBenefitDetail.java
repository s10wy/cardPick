//dto/TransactionBenefitDetail.java
package com.example.choi.recommendation.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TransactionBenefitDetail {
    private String merchant;
    private String category;
    private Long transactionAmount;
    private Long savingAmount;
    private String sourceType;   // BENEFIT, PROMOTION
    private String title;        // 설명용
}
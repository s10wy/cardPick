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
public class CardBenefitRule {
    private String category;
    private String merchantName;
    private String benefitType;   // RATE, AMOUNT, POINT, FREE
    private double benefitValue;
    private String unit;          // PERCENT, WON, POINT, FREE
    private String description;
    private boolean active;

    // 확장 필드
    private Double previousMonthSpendMin;
    private Double previousMonthSpendMax;
    private Double monthlyBenefitLimit;
    private Integer maxBenefitCountPerMonth;
    private Double perTransactionMinAmount;
    private Double perTransactionMaxAmount;
    private String eligibleChannels;   // ONLINE,OFFLINE,APP
}
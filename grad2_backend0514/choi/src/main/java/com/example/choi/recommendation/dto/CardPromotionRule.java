package com.example.choi.recommendation.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CardPromotionRule {
    private String title;
    private String description;
    private LocalDate startDate;
    private LocalDate endDate;
    private boolean active;
    private String category;
    private String merchantName;
    private String benefitType;     // RATE, AMOUNT, POINT
    private double benefitValue;
    private String targetCardName;  // All 또는 콤마 구분 카드명

    // 확장 필드
    private Double promotionMinAmount;
    private Double promotionMaxBenefitAmount;
    private Integer promotionMaxCount;
    private String promotionChannel;              // ONLINE,OFFLINE,APP
    private Boolean stackableWithBaseBenefit;     // 기본 혜택과 중복 허용 여부
}
package com.example.choi.recommendation.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NormalizedTransaction {
    private String category;
    private String merchant;
    private BigDecimal amount;
    private LocalDateTime createdAt;
    private boolean expense;
    private String channel;   // ONLINE, OFFLINE, APP
}
//service/MerchantNormalizer.java
package com.example.choi.recommendation.service;

import org.springframework.stereotype.Component;

@Component
public class MerchantNormalizer {

    public String normalize(String raw) {
        if (raw == null) return "";
        return raw.trim()
                .replace("_", " ")
                .replaceAll("\\s+", " ");
    }
}
//service/CategoryNormalizer.java
package com.example.choi.recommendation.service;

import org.springframework.stereotype.Component;

@Component
public class CategoryNormalizer {

    public String normalize(String raw) {
        if (raw == null) return "ETC";

        String value = raw.trim().toUpperCase();

        switch (value) {
            case "카페":
            case "CAFE":
                return "CAFE";

            case "쇼핑":
            case "SHOPPING":
            case "MART":
                return "SHOPPING";

            case "교통":
            case "TRANSPORT":
            case "TRANSPORTATION":
                return "TRANSPORT";

            case "식비":
            case "FOOD":
                return "FOOD";

            case "구독":
            case "취미":
            case "HOBBY":
            case "CULTURE":
                return "HOBBY";

            case "편의점":
            case "CONVENIENCE":
                return "CONVENIENCE";

            case "주유":
            case "OIL":
                return "OIL";

            case "뷰티":
            case "BEAUTY":
                return "BEAUTY";

            case "급여":
            case "DEPOSIT":
            case "INCOME":
                return "DEPOSIT";

            case "TRAVEL":
            case "여행":
                return "TRAVEL";

            case "DIGITAL":
            case "디지털":
                return "DIGITAL";

            default:
                return "ETC";
        }
    }
}
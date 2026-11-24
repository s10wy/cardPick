package com.example.choi.repo;

import com.example.choi.entity.Card;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CardRepo extends JpaRepository<Card, UUID> {

    List<Card> findByUser_UserId(UUID userId);

    List<Card> findByIsActiveTrue();

    // 추천 기능용: 이메일 기반 + 활성 카드만
    List<Card> findByUser_EmailAndIsActiveTrue(String email);

    // 은행에서 내려준 카드 이름으로 로컬 Card 엔티티 조회
    List<Card> findByCardName(String cardName);
}
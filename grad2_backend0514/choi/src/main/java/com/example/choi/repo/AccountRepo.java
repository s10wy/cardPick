// repo/AccountRepo.java
package com.example.choi.repo;

import com.example.choi.entity.Account;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AccountRepo extends JpaRepository<Account, UUID> {

    // 기존 userId 기반 메서드는 남겨도 되고, 사용하지 않아도 됩니다.
    List<Account> findByUser_UserId(UUID userId);

    // 추천 기능용: 이메일 기반으로 계좌 조회
    List<Account> findByUser_Email(String email);
}
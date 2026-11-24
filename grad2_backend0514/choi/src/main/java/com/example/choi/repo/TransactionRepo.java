// repo/TransactionRepo.java
package com.example.choi.repo;

import com.example.choi.entity.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface TransactionRepo extends JpaRepository<Transaction, UUID> {

    List<Transaction> findByFromAccountOrToAccount(String fromAccount, String toAccount);

    List<Transaction> findByFromAccountInOrToAccountInOrderByCreatedAtDesc(
            List<String> fromAccounts,
            List<String> toAccounts
    );

    List<Transaction> findByCreatedAtAfterOrderByCreatedAtDesc(ZonedDateTime createdAt);

    List<Transaction> findByFromAccountInAndTransactionTypeAndCreatedAtBetweenOrderByCreatedAtDesc(
            List<String> fromAccounts,
            String transactionType,
            ZonedDateTime start,
            ZonedDateTime end
    );

    List<Transaction> findByCreatedAtBetweenOrderByCreatedAtDesc(
            ZonedDateTime start,
            ZonedDateTime end
    );
}
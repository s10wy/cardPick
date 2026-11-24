// TransactionService.java
package com.example.choi;

import com.example.choi.entity.Account;
import com.example.choi.entity.Transaction;
import com.example.choi.entity.User;
import com.example.choi.repo.AccountRepo;
import com.example.choi.repo.TransactionRepo;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.ZonedDateTime;
import java.util.Collections;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TransactionService {

    private final UserService userService;
    private final AccountRepo accountRepo;
    private final TransactionRepo transactionRepo;

    @Value("${app.demo.user-email}")
    private String demoUserEmail;

    public List<Transaction> getCurrentMonthTransactions(String ignoredUserEmail) {
        User demoUser = userService.getUserByEmail(demoUserEmail);

        List<Account> accounts = accountRepo.findByUser_UserId(demoUser.getUserId());
        List<String> accountNumbers = accounts.stream()
                .map(Account::getAccountNumber)
                .toList();

        if (accountNumbers.isEmpty()) {
            return Collections.emptyList();
        }

        ZonedDateTime startOfMonth = ZonedDateTime.now()
                .withDayOfMonth(1)
                .toLocalDate()
                .atStartOfDay(ZonedDateTime.now().getZone());

        return transactionRepo
                .findByFromAccountInOrToAccountInOrderByCreatedAtDesc(accountNumbers, accountNumbers)
                .stream()
                .filter(tx -> tx.getCreatedAt() != null && !tx.getCreatedAt().isBefore(startOfMonth))
                .toList();
    }
}
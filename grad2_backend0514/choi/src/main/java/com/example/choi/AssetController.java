// AssetController.java
package com.example.choi;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import java.util.Map;

@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AssetController {

    private final AssetService assetService;

    @GetMapping("/integrated-assets/{userEmail}")
    public Mono<ResponseEntity<Map<String, Object>>> getAllAssets(
            @PathVariable String userEmail,
            @RequestHeader(value = "Authorization", required = false) String bearerToken
    ) {
        String token = null;

        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            token = bearerToken.substring(7);
        }

        return assetService.getIntegratedAssets(userEmail, token)
                .map(ResponseEntity::ok)
                .onErrorResume(e -> {
                    e.printStackTrace();
                    return Mono.just(ResponseEntity.badRequest().build());
                })
                .defaultIfEmpty(ResponseEntity.notFound().build());
    }
}
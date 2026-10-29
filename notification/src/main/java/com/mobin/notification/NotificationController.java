package com.mobin.notification;

import com.mobin.clients.notification.NotificationRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("api/v1/notification")
@RequiredArgsConstructor
@Slf4j
public class NotificationController {
    private final NotificationService service;
    @PostMapping
    public void sendNotification(@RequestBody NotificationRequest request) {
        log.info("New notification... {}", request);
        service.send(request);
    }
}

package com.mobin.customer;

import com.mobin.amqp.RabbitMQMessageProducer;
import com.mobin.clients.fraud.FraudCheckResponse;
import com.mobin.clients.fraud.FraudClient;
import com.mobin.clients.notification.NotificationClient;
import com.mobin.clients.notification.NotificationRequest;
import io.micrometer.observation.Observation;
import io.micrometer.observation.ObservationRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import javax.management.Notification;

@Service
@RequiredArgsConstructor
public class CustomerService  {
    private final CustomerRepository repository;
    private final FraudClient fraudClient;
    private final RabbitMQMessageProducer rabbitMQMessageProducer;
    private final ObservationRegistry observationRegistry;

    public void registerCustomer(CustomerRegistrationRequest request) {
        Observation.createNotStarted("customer.registration", observationRegistry)
                .observe(() -> {
                    Customer customer = Customer.builder()
                            .firstName(request.firstName())
                            .lastName(request.lastName())
                            .email(request.email())
                            .build();
                    repository.saveAndFlush(customer);
                    FraudCheckResponse fraudCheckResponse = fraudClient.isFraudster(customer.getId());
                    if (fraudCheckResponse.isFraudster()) {
                        throw new IllegalStateException("fraudster");
                    }
                    NotificationRequest notificationRequest = new NotificationRequest(
                            customer.getId(),
                            customer.getEmail(),
                            String.format("Hi %s, welcome to our site...", customer.getFirstName())
                    );
                    rabbitMQMessageProducer.publish(
                            notificationRequest,
                            "internal.exchange",
                            "internal.notification.routing-key"
                    );
                });
    }
}

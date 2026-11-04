package com.mobin.customer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.openfeign.EnableFeignClients;
import org.springframework.context.annotation.PropertySource;
import org.springframework.context.annotation.PropertySources;

@SpringBootApplication(
        scanBasePackages = {
                "com.mobin.customer",
                "com.mobin.amqp"
        }
)
@EnableFeignClients(
        basePackages = "com.mobin.clients"
)
@PropertySources(
        @PropertySource("classpath:clients-${spring.profiles.active:default}.properties")
)
public class CustomerApplication {

    public static void main(String[] args) {
        SpringApplication.run(CustomerApplication.class, args);
    }

}

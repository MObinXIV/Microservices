package com.mobin.fraud;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("api/v1/fraud-check")
@RequiredArgsConstructor
@Slf4j
public class FraudController {
    private final  FraudCheckService service;
    @GetMapping(path = "{customerId}")
    public FraudCheckResponse isFraudster(@PathVariable("customerId")Integer customerID){
        boolean isFraudulentCustomer = service.isFraudulentCustomer(customerID);
        return new FraudCheckResponse(isFraudulentCustomer);
    }

}

package com.example.hazelcastdemo;

import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import javax.annotation.PostConstruct;
import java.net.InetAddress;
import java.net.UnknownHostException;

@Component
public class LoggingContext {

    @PostConstruct
    public void init() {
        // Add Kubernetes context to MDC
        MDC.put("pod_name", System.getenv().getOrDefault("HOSTNAME", "unknown"));
        MDC.put("namespace", System.getenv().getOrDefault("KUBERNETES_NAMESPACE", "default"));
        MDC.put("service", "hazelcast-demo");

        // Add host information
        try {
            MDC.put("host", InetAddress.getLocalHost().getHostName());
        } catch (UnknownHostException e) {
            MDC.put("host", "unknown");
        }

        // Add version info
        MDC.put("version", "1.0.0");
    }
}

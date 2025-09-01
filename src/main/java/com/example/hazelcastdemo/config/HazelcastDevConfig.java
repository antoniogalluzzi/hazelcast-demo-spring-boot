package com.example.hazelcastdemo.config;

import com.hazelcast.config.*;
import com.hazelcast.core.Hazelcast;
import com.hazelcast.core.HazelcastInstance;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

/**
 * Hazelcast configuration for development environment
 * Uses multicast discovery for local development
 */
@Configuration
@ConditionalOnProperty(name = "spring.profiles.active", havingValue = "dev")
public class HazelcastDevConfig {

    private static final String CLUSTER_NAME = "hazelcast-demo-cluster";
    private static final String INSTANCE_NAME = "hazelcast-demo-dev";
    private static final int BASE_PORT = 5701;
    private static final String MULTICAST_GROUP = "224.2.2.3";
    private static final int MULTICAST_PORT = 54327;

    @Bean
    @Primary
    public Config hazelcastConfig() {
        Config config = new Config()
                .setClusterName(CLUSTER_NAME)
                .setInstanceName(INSTANCE_NAME);

        configureNetwork(config);
        configureDiscovery(config);
        configureProperties(config);

        return config;
    }

    @Bean
    @Primary
    public HazelcastInstance hazelcastInstance(Config hazelcastConfig) {
        return Hazelcast.newHazelcastInstance(hazelcastConfig);
    }

    private void configureNetwork(Config config) {
        config.getNetworkConfig()
                .setPort(BASE_PORT)
                .setPortAutoIncrement(true)
                .setPortCount(10);
    }

    private void configureDiscovery(Config config) {
        JoinConfig joinConfig = config.getNetworkConfig().getJoin();

        // Enable multicast for local development
        joinConfig.getMulticastConfig()
                .setEnabled(true)
                .setMulticastGroup(MULTICAST_GROUP)
                .setMulticastPort(MULTICAST_PORT)
                .setMulticastTimeoutSeconds(2)
                .setMulticastTimeToLive(32);

        // Disable all other discovery methods
        joinConfig.getTcpIpConfig().setEnabled(false);
        joinConfig.getAwsConfig().setEnabled(false);
        joinConfig.getGcpConfig().setEnabled(false);
        joinConfig.getAzureConfig().setEnabled(false);
        joinConfig.getKubernetesConfig().setEnabled(false);
        joinConfig.getEurekaConfig().setEnabled(false);
    }

    private void configureProperties(Config config) {
        config.setProperty("hazelcast.logging.type", "slf4j")
              .setProperty("hazelcast.phone.home.enabled", "false")
              .setProperty("hazelcast.shutdownhook.enabled", "true")
              .setProperty("hazelcast.operation.call.timeout.millis", "60000")
              .setProperty("hazelcast.graceful.shutdown.max.wait", "600");
    }
}

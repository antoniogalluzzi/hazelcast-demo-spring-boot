package com.example.hazelcastdemo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@SpringBootApplication
@EnableCaching
@EnableJpaRepositories
public class HazelcastDemoApplication {

	public static void main(String[] args) {
		SpringApplication.run(HazelcastDemoApplication.class, args);
	}

}

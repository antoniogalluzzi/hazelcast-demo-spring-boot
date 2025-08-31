package com.example.hazelcastdemo;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Hazelcast Demo API")
                        .version("1.0.0")
                        .description("API per dimostrazione cache distribuita con Hazelcast")
                        .contact(new Contact()
                                .name("Team Sviluppo")
                                .email("dev@company.com"))
                        .license(new License()
                                .name("Apache 2.0")
                                .url("http://www.apache.org/licenses/LICENSE-2.0")))
                .addServersItem(new Server()
                        .url("http://localhost:8080")
                        .description("Server di sviluppo locale"))
                .addServersItem(new Server()
                        .url("https://hazelcast-demo.apps.openshift.com")
                        .description("Server OpenShift produzione"));
    }
}

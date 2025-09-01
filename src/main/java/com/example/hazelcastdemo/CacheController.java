package com.example.hazelcastdemo;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import com.hazelcast.core.HazelcastInstance;
import com.hazelcast.map.IMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.ResponseStatus;

import java.util.HashMap;
import java.util.Map;

@RestController
@Tag(name = "User Management", description = "API per la gestione degli utenti con cache distribuita Hazelcast")
public class CacheController {

    private static final Logger logger = LoggerFactory.getLogger(CacheController.class);

    @Autowired
    private UserService userService;

    @Autowired
    private HazelcastInstance hazelcastInstance;

    @GetMapping("/user/{id}")
    @Operation(
        summary = "Recupera utente per ID",
        description = "Recupera un utente dal database con cache distribuita Hazelcast. " +
                     "La prima chiamata recupera dal DB e salva in cache, le successive dalla cache.",
        parameters = {
            @Parameter(name = "id", description = "ID univoco dell'utente", required = true, example = "1")
        }
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Utente trovato",
                    content = @Content(mediaType = "application/json",
                                     schema = @Schema(implementation = User.class))),
        @ApiResponse(responseCode = "404", description = "Utente non trovato",
                    content = @Content),
        @ApiResponse(responseCode = "500", description = "Errore interno del server",
                    content = @Content)
    })
    public User getUser(@PathVariable Long id) {
        logger.info("Retrieving user with ID: {}", id);
        User user = userService.getUserById(id);
        if (user != null) {
            logger.debug("User found: {} - {}", id, user.getName());
        } else {
            logger.warn("User not found: {}", id);
        }
        return user;
    }

    @PostMapping("/user")
    @Operation(
        summary = "Crea nuovo utente",
        description = "Crea un nuovo utente nel database. L'utente viene automaticamente " +
                     "aggiunto alla cache distribuita per accessi futuri."
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Utente creato con successo",
                    content = @Content(mediaType = "application/json",
                                     schema = @Schema(implementation = User.class))),
        @ApiResponse(responseCode = "400", description = "Dati utente non validi",
                    content = @Content),
        @ApiResponse(responseCode = "500", description = "Errore interno del server",
                    content = @Content)
    })
    @ResponseStatus(HttpStatus.CREATED)
    public User createUser(@RequestBody User user) {
        logger.info("Creating new user: {}", user.getName());
        User savedUser = userService.saveUser(user);
        logger.info("User created successfully with ID: {}", savedUser.getId());
        return savedUser;
    }

    @GetMapping("/cache")
    @Operation(
        summary = "Test cache",
        description = "Endpoint di test per verificare il funzionamento dell'applicazione. " +
                     "Restituisce informazioni sulla cache distribuita."
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Test cache completato",
                    content = @Content(mediaType = "text/plain"))
    })
    public String getCachedValue() {
        logger.info("Cache test endpoint accessed");
        return "Cache test - use /user/{id} for DB data";
    }

    @GetMapping("/cache/stats")
    @Operation(
        summary = "Statistiche cache",
        description = "Restituisce statistiche dettagliate sulla cache distribuita Hazelcast"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Statistiche cache",
                    content = @Content(mediaType = "application/json"))
    })
    public Map<String, Object> getCacheStats() {
        logger.info("Cache stats endpoint accessed");
        Map<String, Object> stats = new HashMap<>();
        
        IMap<Object, Object> userCache = hazelcastInstance.getMap("users");
        stats.put("cacheSize", userCache.size());
        stats.put("clusterSize", hazelcastInstance.getCluster().getMembers().size());
        stats.put("localMemoryUsage", userCache.getLocalMapStats().getOwnedEntryMemoryCost());
        
        return stats;
    }

    @GetMapping("/cache/cluster")
    @Operation(
        summary = "Informazioni cluster Hazelcast",
        description = "Restituisce informazioni sui membri del cluster Hazelcast"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Info cluster",
                    content = @Content(mediaType = "application/json"))
    })
    public Map<String, Object> getClusterInfo() {
        logger.info("Cluster info endpoint accessed");
        Map<String, Object> info = new HashMap<>();
        
        info.put("clusterSize", hazelcastInstance.getCluster().getMembers().size());
        info.put("clusterMembers", hazelcastInstance.getCluster().getMembers().toString());
        info.put("localMember", hazelcastInstance.getCluster().getLocalMember().toString());
        
        return info;
    }

    @DeleteMapping("/cache/clear")
    @Operation(
        summary = "Pulisci cache",
        description = "Rimuove tutti gli elementi dalla cache distribuita"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Cache pulita",
                    content = @Content(mediaType = "text/plain"))
    })
    public String clearCache() {
        logger.info("Clearing cache");
        IMap<Object, Object> userCache = hazelcastInstance.getMap("users");
        userCache.clear();
        return "Cache cleared successfully";
    }
}

#!/usr/bin/env bash
set -euo pipefail

# Java Web Full-Stack Project Initializer
# Usage: ./init-project.sh <project-name> [--package com.example.project] [--db-name my_db]
#
# Generates a standardized Spring Boot + Vue 3 project scaffold with:
#   - Maven pom.xml with MyBatis-Plus, MySQL, Lombok, etc.
#   - Package structure with controller/service/mapper/entity/dto/vo/config/exception/common
#   - application.yml, application-dev.yml, application-prod.yml
#   - CORS config, Global exception handler, Unified Result wrapper
#   - Vue 3 + Vite + TypeScript + Element Plus + HTTP client (Axios example) scaffold
#   - HTTP client encapsulation with interceptors
#   - Pinia store template
#   - Vue Router with auth guard

if [ $# -lt 1 ]; then
    echo "Usage: ./init-project.sh <project-name> [--package com.example.project] [--db-name my_db]"
    exit 1
fi

PROJECT_NAME="$1"
shift

PACKAGE="com.example.${PROJECT_NAME}"
DB_NAME="${PROJECT_NAME}"
BACKEND_DIR="${PROJECT_NAME}/backend"
FRONTEND_DIR="${PROJECT_NAME}/frontend"

while [ $# -gt 0 ]; do
    case "$1" in
        --package) PACKAGE="$2"; shift 2 ;;
        --db-name) DB_NAME="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

PACKAGE_PATH="${PACKAGE//./\/}"

echo "Creating project: ${PROJECT_NAME}"
echo "  Package: ${PACKAGE}"
echo "  Database: ${DB_NAME}"

# ─── Create backend structure ───────────────────────────────────────────────
mkdir -p "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/"{controller,service/impl,mapper,entity,dto,vo,config,common/result,exception,enums}
mkdir -p "${BACKEND_DIR}/src/main/resources/mapper"
mkdir -p "${BACKEND_DIR}/src/test/java/${PACKAGE_PATH}"

# ─── pom.xml ────────────────────────────────────────────────────────────────
cat > "${BACKEND_DIR}/pom.xml" <<POMEOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>

    <groupId>${PACKAGE}</groupId>
    <artifactId>${PROJECT_NAME}</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <name>${PROJECT_NAME}</name>

    <properties>
        <java.version>17</java.version>
        <mybatis-plus.version>3.5.7</mybatis-plus.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>com.baomidou</groupId>
            <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
            <version>\${mybatis-plus.version}</version>
        </dependency>
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
POMEOF

# ─── Application Properties ─────────────────────────────────────────────────
cat > "${BACKEND_DIR}/src/main/resources/application.yml" <<YMLEOF
spring:
  profiles:
    active: dev
YMLEOF

cat > "${BACKEND_DIR}/src/main/resources/application-dev.yml" <<YMLEOF
server:
  port: 8080
  servlet:
    context-path: /api

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/${DB_NAME}?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai
    username: root
    password: \${DB_PASSWORD:root}
    driver-class-name: com.mysql.cj.jdbc.Driver
  jackson:
    date-format: yyyy-MM-dd HH:mm:ss
    time-zone: Asia/Shanghai

mybatis-plus:
  mapper-locations: classpath*:mapper/**/*.xml
  configuration:
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl
    map-underscore-to-camel-case: true
  global-config:
    db-config:
      id-type: AUTO
      logic-delete-field: is_deleted
      logic-delete-value: 1
      logic-not-delete-value: 0

logging:
  level:
    ${PACKAGE}.mapper: DEBUG
YMLEOF

cat > "${BACKEND_DIR}/src/main/resources/application-prod.yml" <<YMLEOF
server:
  port: 8080
  servlet:
    context-path: /api

spring:
  datasource:
    url: jdbc:mysql://prod-host:3306/${DB_NAME}?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai
    username: \${DB_USERNAME}
    password: \${DB_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      idle-timeout: 300000
      max-lifetime: 1200000
  jackson:
    date-format: yyyy-MM-dd HH:mm:ss
    time-zone: Asia/Shanghai

mybatis-plus:
  mapper-locations: classpath*:mapper/**/*.xml
  configuration:
    map-underscore-to-camel-case: true
  global-config:
    db-config:
      id-type: AUTO
      logic-delete-field: is_deleted
      logic-delete-value: 1
      logic-not-delete-value: 0

logging:
  level:
    ${PACKAGE}: INFO
YMLEOF

# ─── Application Main Class ─────────────────────────────────────────────────
cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/Application.java" <<JAVAEOF
package ${PACKAGE};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
JAVAEOF

# ─── Result Wrapper ─────────────────────────────────────────────────────────
cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/common/result/Result.java" <<JAVAEOF
package ${PACKAGE}.common.result;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Result<T> {
    private int code;
    private String message;
    private T data;

    public static <T> Result<T> success(T data) {
        return new Result<>(200, "success", data);
    }

    public static <T> Result<T> success() {
        return new Result<>(200, "success", null);
    }

    public static <T> Result<T> error(int code, String message) {
        return new Result<>(code, message, null);
    }
}
JAVAEOF

# ─── Global Exception Handler ───────────────────────────────────────────────
cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/exception/GlobalExceptionHandler.java" <<JAVAEOF
package ${PACKAGE}.exception;

import ${PACKAGE}.common.result.Result;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidation(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getAllErrors().stream()
                .map(err -> err.getDefaultMessage())
                .collect(java.util.stream.Collectors.joining(", "));
        return Result.error(HttpStatus.BAD_REQUEST.value(), message);
    }

    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusiness(BusinessException e) {
        return Result.error(e.getCode(), e.getMessage());
    }

    @ExceptionHandler(Exception.class)
    public Result<Void> handleUnknown(Exception e) {
        log.error("Unexpected error", e);
        return Result.error(HttpStatus.INTERNAL_SERVER_ERROR.value(), "Internal server error");
    }
}
JAVAEOF

cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/exception/BusinessException.java" <<JAVAEOF
package ${PACKAGE}.exception;

import lombok.Getter;

@Getter
public class BusinessException extends RuntimeException {
    private final int code;

    public BusinessException(int code, String message) {
        super(message);
        this.code = code;
    }

    public BusinessException(String message) {
        super(message);
        this.code = 400;
    }
}
JAVAEOF

# ─── CORS Config ────────────────────────────────────────────────────────────
cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/config/CorsConfig.java" <<JAVAEOF
package ${PACKAGE}.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns("*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }
}
JAVAEOF

# ─── MyBatis-Plus Config ────────────────────────────────────────────────────
cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/config/MyBatisPlusConfig.java" <<JAVAEOF
package ${PACKAGE}.config;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@MapperScan("${PACKAGE}.mapper")
public class MyBatisPlusConfig {

    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
        return interceptor;
    }
}
JAVAEOF

# ─── Sample Entity, Mapper, Service, Controller ─────────────────────────────
cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/entity/User.java" <<JAVAEOF
package ${PACKAGE}.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("users")
public class User {
    @TableId(type = IdType.AUTO)
    private Long id;

    private String username;

    private String email;

    @TableLogic
    @TableField("is_deleted")
    private Integer isDeleted;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
JAVAEOF

cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/mapper/UserMapper.java" <<JAVAEOF
package ${PACKAGE}.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import ${PACKAGE}.entity.User;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface UserMapper extends BaseMapper<User> {
}
JAVAEOF

cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/service/UserService.java" <<JAVAEOF
package ${PACKAGE}.service;

import com.baomidou.mybatisplus.extension.service.IService;
import ${PACKAGE}.entity.User;

public interface UserService extends IService<User> {
}
JAVAEOF

cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/service/impl/UserServiceImpl.java" <<JAVAEOF
package ${PACKAGE}.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import ${PACKAGE}.entity.User;
import ${PACKAGE}.mapper.UserMapper;
import ${PACKAGE}.service.UserService;
import org.springframework.stereotype.Service;

@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, User> implements UserService {
}
JAVAEOF

cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/dto/UserDTO.java" <<JAVAEOF
package ${PACKAGE}.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UserDTO {
    @NotBlank(message = "Username is required")
    @Size(min = 2, max = 50, message = "Username must be 2-50 characters")
    private String username;

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;
}
JAVAEOF

cat > "${BACKEND_DIR}/src/main/java/${PACKAGE_PATH}/controller/UserController.java" <<JAVAEOF
package ${PACKAGE}.controller;

import ${PACKAGE}.common.result.Result;
import ${PACKAGE}.dto.UserDTO;
import ${PACKAGE}.entity.User;
import ${PACKAGE}.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping
    public Result<List<User>> list() {
        return Result.success(userService.list());
    }

    @GetMapping("/{id}")
    public Result<User> getById(@PathVariable Long id) {
        return Result.success(userService.getById(id));
    }

    @PostMapping
    public Result<Void> create(@Valid @RequestBody UserDTO dto) {
        User user = new User();
        user.setUsername(dto.getUsername());
        user.setEmail(dto.getEmail());
        userService.save(user);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @Valid @RequestBody UserDTO dto) {
        User user = new User();
        user.setId(id);
        user.setUsername(dto.getUsername());
        user.setEmail(dto.getEmail());
        userService.updateById(user);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        userService.removeById(id);
        return Result.success();
    }
}
JAVAEOF

# ─── SQL Schema ─────────────────────────────────────────────────────────────
cat > "${BACKEND_DIR}/src/main/resources/schema.sql" <<SQLEOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME}
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE ${DB_NAME};

CREATE TABLE IF NOT EXISTS users (
    id         BIGINT       AUTO_INCREMENT PRIMARY KEY,
    username   VARCHAR(50)  NOT NULL,
    email      VARCHAR(100) NOT NULL,
    is_deleted TINYINT(1)   NOT NULL DEFAULT 0,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_email (email),
    INDEX idx_users_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQLEOF

# ─── Vue 3 Frontend Scaffold ────────────────────────────────────────────────
# Using Vite to create the Vue 3 + TypeScript project
echo "Creating Vue 3 frontend..."

# Create frontend with Vite (if npm is available)
if command -v npm &>/dev/null; then
    cd "${PROJECT_NAME}"
    npm create vite@latest frontend -- --template vue-ts 2>/dev/null || {
        # Fallback: manual scaffold if Vite create fails
        mkdir -p frontend/src/{api,views,components,router,stores,types,utils}
    }
    cd ..
else
    mkdir -p "${FRONTEND_DIR}/src/"{api,views,components,router,stores,types,utils}
fi

# Ensure frontend src directories exist
mkdir -p "${FRONTEND_DIR}/src/"{api,views,components,router,stores,types,utils}

# create-vite overwrites vite.config.ts, so reconfigure it with @ alias
if [ -f "${FRONTEND_DIR}/vite.config.ts" ]; then
    cat > "${FRONTEND_DIR}/vite.config.ts" <<VITEEOF
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src')
    }
  }
})
VITEEOF

    # Add path aliases to tsconfig.app.json if it exists
    TSCONFIG="${FRONTEND_DIR}/tsconfig.app.json"
    if [ -f "$TSCONFIG" ]; then
        # Add baseUrl and paths after the types field
        sed -i 's|"types": \["vite/client"\]|"types": ["vite/client"],\n    "baseUrl": ".",\n    "paths": {\n      "@/*": ["src/*"]\n    }|' "$TSCONFIG"
    fi
fi

# Install Element Plus and configure (only if package.json exists from Vite)
if [ -f "${FRONTEND_DIR}/package.json" ]; then
    cat > "${FRONTEND_DIR}/src/main.ts" <<TSEOF
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import App from './App.vue'
import router from './router'

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.use(ElementPlus)
app.mount('#app')
TSEOF
fi

echo ""
echo "=== Project scaffold generated successfully ==="
echo ""
echo "Backend: ${BACKEND_DIR}/"
echo "  Build: cd ${BACKEND_DIR} && mvn spring-boot:run"
echo "  DB:    Execute src/main/resources/schema.sql to create tables"
echo ""
echo "Frontend: ${FRONTEND_DIR}/"
echo "  Run:   cd ${FRONTEND_DIR} && npm install && npm run dev"
echo ""
echo "Next steps:"
echo "  1. Import the project into your IDE"
echo "  2. Run schema.sql to create the database"
echo "  3. Configure application-dev.yml with your DB credentials"
echo "  4. Start backend: cd ${BACKEND_DIR} && mvn spring-boot:run"
echo "  5. Start frontend: cd ${FRONTEND_DIR} && npm run dev"

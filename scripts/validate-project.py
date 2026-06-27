#!/usr/bin/env python3
"""
Java Web Full-Stack Project Validator

Scans a Java Web full-stack project (Spring Boot + Vue 3 example pattern)
for common violations of the layered architecture rules.

Usage:
    python validate-project.py /path/to/project

The script checks:
    - Backend: package structure, CORS config, global exception handler,
               Result wrapper, @Transactional usage, DTO/Entity separation
    - Frontend: HTTP client encapsulation, API module structure,
                loading/error/empty states, Pinia stores
    - Common issues: hardcoded secrets, missing validation, SQL injection risks
"""

import os
import re
import sys
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class Issue:
    severity: str  # ERROR or WARNING
    category: str
    message: str
    file: str = ""
    line: Optional[int] = None

    def __str__(self):
        loc = f":{self.line}" if self.line else ""
        return f"[{self.severity}] [{self.category}] {self.file}{loc} - {self.message}"


@dataclass
class ScanResult:
    issues: List[Issue] = field(default_factory=list)
    passed: int = 0
    failed: int = 0


class ProjectScanner:
    def __init__(self, root: Path):
        self.root = root
        self.backend_root = self._find_backend()
        self.frontend_root = self._find_frontend()
        self.result = ScanResult()

    def _find_backend(self) -> Optional[Path]:
        """Find the backend module (pom.xml or build.gradle)."""
        for p in [self.root, self.root / "backend", self.root / "server"]:
            if (p / "pom.xml").exists() or (p / "build.gradle").exists():
                return p

        # Search recursively
        for p in self.root.rglob("pom.xml"):
            return p.parent
        for p in self.root.rglob("build.gradle"):
            return p.parent
        return None

    def _find_frontend(self) -> Optional[Path]:
        """Find the frontend module (package.json with Vue or Vite)."""
        for p in [self.root, self.root / "frontend", self.root / "web", self.root / "vue"]:
            pkg = p / "package.json"
            if pkg.exists():
                content = pkg.read_text()
                if "vue" in content or "vite" in content:
                    return p
        return None

    def _find_java_files(self, base: Path, pattern: str = "**/*.java") -> List[Path]:
        return list(base.rglob(pattern))

    def _find_package_root(self) -> Optional[Path]:
        """Find the Java package root (where Application.java lives)."""
        if not self.backend_root:
            return None
        for f in self._find_java_files(self.backend_root, "**/Application.java"):
            return f.parent
        return None

    def scan_backend(self):
        if not self.backend_root:
            self.result.issues.append(Issue(
                "WARNING", "structure", "No backend module found (pom.xml or build.gradle)"
            ))
            return

        pkg_root = self._find_package_root()
        if not pkg_root:
            self.result.issues.append(Issue(
                "WARNING", "structure", "No Application.java found in backend"
            ))
            return

        src_base = pkg_root.parent

        # Check required packages exist (under the project package root)
        required_packages = ["controller", "service", "mapper", "entity", "dto", "config", "exception"]
        for pkg in required_packages:
            pkg_dir = pkg_root / pkg
            if not pkg_dir.exists():
                self.result.issues.append(Issue(
                    "WARNING", "structure",
                    f"Package '{pkg}' not found under {pkg_root.name} — consider creating it under {pkg_root.name}/{pkg}",
                    str(pkg_root.relative_to(self.backend_root))
                ))

        # Check CORS configuration
        cors_files = list(src_base.rglob("*Cors*.java")) + list(src_base.rglob("*Cors*.kt"))
        if not cors_files:
            self.result.issues.append(Issue(
                "WARNING", "cors",
                "No CORS configuration found — frontend may get CORS errors"
            ))

        # Check Global Exception Handler
        exc_handler = list(src_base.rglob("GlobalException*.java"))
        if not exc_handler:
            self.result.issues.append(Issue(
                "WARNING", "exception",
                "No GlobalExceptionHandler found — unhandled exceptions return stack traces to clients"
            ))

        # Check Result wrapper
        result_files = list(src_base.rglob("Result.java"))
        if not result_files:
            self.result.issues.append(Issue(
                "WARNING", "api",
                "No unified Result<T> wrapper found — API responses may lack consistent format"
            ))

        # Check for @Transactional without rollbackFor
        for java_file in self._find_java_files(self.backend_root):
            content = java_file.read_text()
            for match in re.finditer(r'@Transactional(?!.*rollbackFor)', content):
                line_num = content[:match.start()].count('\n') + 1
                self.result.issues.append(Issue(
                    "WARNING", "transaction",
                    "@Transactional without rollbackFor=Exception.class — checked exceptions won't trigger rollback",
                    str(java_file.relative_to(self.backend_root)), line_num
                ))

        # Check for SQL injection risk (${} in MyBatis XML)
        for xml_file in self.backend_root.rglob("*.xml"):
            if "mapper" in str(xml_file):
                content = xml_file.read_text()
                for match in re.finditer(r'\$\{', content):
                    line_num = content[:match.start()].count('\n') + 1
                    self.result.issues.append(Issue(
                        "WARNING", "security",
                        "Using ${} in MyBatis XML — potential SQL injection risk. Use #{} instead",
                        str(xml_file.relative_to(self.backend_root)), line_num
                    ))

        # Check for hardcoded secrets
        secrets_patterns = [
            (r'password\s*=\s*["\'](?!\${)[^"\']+["\']', "Hardcoded password in properties"),
            (r'jdbc:mysql://[^:]+:[^@]+@', "Hardcoded DB credentials in JDBC URL"),
        ]
        for props_file in list(self.backend_root.rglob("application*.yml")) + \
                          list(self.backend_root.rglob("application*.properties")):
            content = props_file.read_text()
            for pattern, msg in secrets_patterns:
                for match in re.finditer(pattern, content, re.IGNORECASE):
                    line_num = content[:match.start()].count('\n') + 1
                    self.result.issues.append(Issue(
                        "WARNING", "security", msg,
                        str(props_file.relative_to(self.backend_root)), line_num
                    ))

        # Check for Entity exposed in Controller return type
        for java_file in self._find_java_files(src_base / "controller"):
            content = java_file.read_text()
            # Find methods returning Entity types (not DTO/VO)
            for match in re.finditer(r'public\s+Result<(?!.*DTO|.*VO)(\w+)>', content):
                line_num = content[:match.start()].count('\n') + 1
                entity_name = match.group(1)
                # Check if that type is in entity package (import)
                if f"import {self._guess_package(src_base)}.entity.{entity_name}" in content:
                    self.result.issues.append(Issue(
                        "WARNING", "architecture",
                        f"Returning Entity '{entity_name}' from controller — use DTO/VO instead",
                        str(java_file.relative_to(self.backend_root)), line_num
                    ))

    def _guess_package(self, src_base: Path) -> str:
        """Guess the base package from directory structure."""
        parts = src_base.parts
        src_index = -1
        for i, p in enumerate(parts):
            if p in ("java", "kotlin"):
                src_index = i
                break
        if src_index >= 0 and src_index + 1 < len(parts):
            return ".".join(parts[src_index + 1:])
        return "com.example"

    def scan_frontend(self):
        if not self.frontend_root:
            self.result.issues.append(Issue(
                "WARNING", "structure", "No Vue 3 frontend module found"
            ))
            return

        src = self.frontend_root / "src"

        # Check HTTP client encapsulation (Axios / fetch wrapper / etc.)
        utils_dir = src / "utils"
        api_dir = src / "api"
        http_file = None
        for f in ["http.ts", "request.ts", "client.ts", "axios.ts"]:
            if (utils_dir / f).exists():
                http_file = utils_dir / f
                break

        if not http_file:
            for f in ["http.ts", "request.ts", "client.ts", "axios.ts"]:
                if (api_dir / f).exists():
                    http_file = api_dir / f
                    break

        if not http_file:
            self.result.issues.append(Issue(
                "WARNING", "frontend",
                "No HTTP client encapsulation found (http.ts/request.ts) — API calls may lack interceptors"
            ))
        else:
            content = http_file.read_text()
            # Check for either Axios interceptors or fetch wrapper patterns
            has_interceptors = "interceptors.request" in content or "interceptors.response" in content
            has_fetch_wrapper = "async function request" in content or "const request =" in content
            if not has_interceptors and not has_fetch_wrapper:
                self.result.issues.append(Issue(
                    "WARNING", "frontend",
                    "HTTP client may lack request/response interceptors — token and errors may not be handled uniformly"
                ))

        # Check API module structure
        if not api_dir.exists() or not list(api_dir.glob("*.ts")):
            self.result.issues.append(Issue(
                "WARNING", "frontend",
                "No API modules found in src/api/ — define API calls in domain-specific files"
            ))

        # Check Pinia stores
        stores_dir = src / "stores"
        if not stores_dir.exists() or not list(stores_dir.glob("*.ts")):
            self.result.issues.append(Issue(
                "WARNING", "frontend",
                "No Pinia stores found — consider using Pinia for state management"
            ))

        # Check for loading/error/empty states in views
        for vue_file in (src / "views").rglob("*.vue") if (src / "views").exists() else []:
            content = vue_file.read_text()
            if "loading" not in content:
                self.result.issues.append(Issue(
                    "WARNING", "frontend",
                    "View may lack loading state handling",
                    str(vue_file.relative_to(self.frontend_root))
                ))

        # Check Vue Router exists and has auth guard
        router_file = src / "router" / "index.ts"
        if router_file.exists():
            content = router_file.read_text()
            if "beforeEach" not in content:
                self.result.issues.append(Issue(
                    "WARNING", "frontend",
                    "Router navigation guard (beforeEach) not found — auth checks may be missing"
                ))
        else:
            self.result.issues.append(Issue(
                "WARNING", "frontend",
                "No src/router/index.ts found"
            ))

    def scan_maven(self):
        """Scan pom.xml for missing dependencies or incorrect versions."""
        if not self.backend_root:
            return
        for pom in [self.backend_root / "pom.xml"]:
            if not pom.exists():
                continue
            content = pom.read_text()
            # Check for common missing dependencies
            # (We don't flag if MyBatis-Plus is replaced by raw MyBatis)
            has_db = any(dep in content for dep in [
                "mysql-connector", "mybatis", "mybatis-plus",
                "postgresql", "oracle"
            ])
            if not has_db:
                self.result.issues.append(Issue(
                    "WARNING", "dependency",
                    "No database driver dependency found in pom.xml"
                ))

            has_validation = "spring-boot-starter-validation" in content
            if not has_validation:
                self.result.issues.append(Issue(
                    "WARNING", "dependency",
                    "spring-boot-starter-validation not found — consider adding it for @Valid support"
                ))

            has_lombok = "lombok" in content or "mapstruct" in content
            if not has_lombok:
                self.result.issues.append(Issue(
                    "WARNING", "dependency",
                    "Lombok not found — consider adding it to reduce boilerplate"
                ))

    def scan(self) -> ScanResult:
        """Run all scans and return results."""
        print(f"Scanning project: {self.root}")
        print(f"  Backend root: {self.backend_root or 'Not found'}")
        print(f"  Frontend root: {self.frontend_root or 'Not found'}")
        print()

        self.scan_backend()
        self.scan_frontend()
        self.scan_maven()

        return self.result


def print_results(result: ScanResult):
    if not result.issues:
        print("✅ No issues found!")
        return

    errors = [i for i in result.issues if i.severity == "ERROR"]
    warnings = [i for i in result.issues if i.severity == "WARNING"]

    if errors:
        print(f"\n{'='*60}")
        print(f"ERRORS ({len(errors)}):")
        print(f"{'='*60}")
        for issue in errors:
            print(f"  {issue}")

    if warnings:
        print(f"\n{'='*60}")
        print(f"WARNINGS ({len(warnings)}):")
        print(f"{'='*60}")
        for issue in warnings:
            print(f"  {issue}")

    print(f"\n{'='*60}")
    print(f"Summary: {len(errors)} errors, {len(warnings)} warnings")
    print(f"{'='*60}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python validate-project.py <project-path>")
        sys.exit(1)

    path = Path(sys.argv[1]).resolve()
    if not path.exists():
        print(f"Error: Path '{path}' does not exist")
        sys.exit(1)

    scanner = ProjectScanner(path)
    result = scanner.scan()
    print_results(result)

    # Exit with error code if any ERROR-level issues found
    errors = [i for i in result.issues if i.severity == "ERROR"]
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()

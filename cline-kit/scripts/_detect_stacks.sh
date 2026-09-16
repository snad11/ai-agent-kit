#!/usr/bin/env bash
# Shared stack detection for agent-sync.sh, agent-init.sh, and repair-sentinel.sh.
#
# Sourced, never executed. Callers must have TARGET set to the absolute project path.
# Prints one rules-module basename per line (e.g. backend-laravel), sorted and unique,
# or nothing when no known stack is present.
#
# Three callers used to carry three copies of this logic, which is how a project ends
# up with a rules file the sync no longer reproduces. Keep it here only.

detect_stacks() {
    : "${TARGET:?detect_stacks: TARGET is not set}"
    local d=()
    if find "$TARGET" -maxdepth 4 -name "nest-cli.json" 2>/dev/null | head -1 | grep -q .; then d+=("backend-nestjs"); fi
    if find "$TARGET" -maxdepth 4 -name "next.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then d+=("frontend-next"); fi
    if find "$TARGET" -maxdepth 4 -name "nuxt.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then d+=("frontend-nuxt"); d+=("frontend-vue"); fi
    if find "$TARGET" -maxdepth 4 -name "vite.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q . \
       && find "$TARGET" -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"react"' {} \; 2>/dev/null | head -1 | grep -q . \
       && ! find "$TARGET" -maxdepth 4 -name "next.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q . \
       && ! find "$TARGET" -maxdepth 4 -name "nuxt.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then d+=("frontend-react"); fi
    if find "$TARGET" -maxdepth 4 -name "vite.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q . \
       && find "$TARGET" -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"vue"' {} \; 2>/dev/null | head -1 | grep -q . \
       && ! find "$TARGET" -maxdepth 4 -name "nuxt.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then d+=("frontend-vue"); fi
    if find "$TARGET" -maxdepth 3 -name "artisan" 2>/dev/null | head -1 | grep -q .; then d+=("backend-laravel"); fi
    if find "$TARGET" -maxdepth 3 -name "manage.py" 2>/dev/null | head -1 | grep -q .; then d+=("backend-django"); fi
    if grep -rIl --include="pyproject.toml" --include="requirements*.txt" -e "fastapi" "$TARGET" 2>/dev/null | head -1 | grep -q .; then d+=("backend-fastapi"); fi
    if find "$TARGET" -maxdepth 3 -name "pubspec.yaml" 2>/dev/null | head -1 | grep -q .; then d+=("mobile-flutter"); fi
    if find "$TARGET" -maxdepth 3 -name "metro.config.*" 2>/dev/null | head -1 | grep -q .; then d+=("mobile-react-native"); fi
    [ ${#d[@]} -eq 0 ] && return 0
    printf '%s\n' "${d[@]}" | sort -u
}

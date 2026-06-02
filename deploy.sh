#!/bin/bash

################################################################################
# Fittrack Production Deployment Script
# 
# Usage: ./deploy.sh [--skip-git] [--skip-restart]
# 
# This script automates the complete deployment process:
# - Pulls latest changes from main branch
# - Loads environment configuration
# - Installs dependencies
# - Runs database migrations
# - Compiles Elixir code
# - Deploys and bundles assets
# - Creates production release
# - Restarts the service
# - Verifies deployment
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}"
DEPLOY_LOG="${APP_DIR}/deploy.log"
SKIP_GIT=false
SKIP_RESTART=false
START_TIME=$(date +%s)

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${DEPLOY_LOG}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${DEPLOY_LOG}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${DEPLOY_LOG}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${DEPLOY_LOG}"
}

cleanup() {
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        local duration=$(( $(date +%s) - START_TIME ))
        log_success "Deployment completed successfully in ${duration}s"
    else
        log_error "Deployment failed with exit code $exit_code"
    fi
    exit $exit_code
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-git)
                SKIP_GIT=true
                shift
                ;;
            --skip-restart)
                SKIP_RESTART=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

step_git_pull() {
    if [ "$SKIP_GIT" = true ]; then
        log_warn "Skipping git pull"
        return
    fi
    
    log_info "Pulling latest changes from main branch..."
    cd "${APP_DIR}"
    git pull --ff-only origin main || {
        log_error "Failed to pull from git. Please resolve conflicts manually."
        exit 1
    }
    log_success "Git pull completed"
}

step_load_environment() {
    log_info "Loading environment configuration..."
    if [ ! -f "${APP_DIR}/fittrack.env" ]; then
        log_error "fittrack.env not found at ${APP_DIR}"
        exit 1
    fi
    set -a
    source "${APP_DIR}/fittrack.env"
    set +a
    log_success "Environment loaded"
}

step_get_dependencies() {
    log_info "Fetching dependencies..."
    cd "${APP_DIR}"
    MIX_ENV=prod mix deps.get --only prod >> "${DEPLOY_LOG}" 2>&1
    log_success "Dependencies fetched"
}

step_compile() {
    log_info "Compiling Elixir code..."
    cd "${APP_DIR}"
    MIX_ENV=prod mix compile >> "${DEPLOY_LOG}" 2>&1
    log_success "Compilation complete"
}

step_migrate_database() {
    log_info "Running database migrations..."
    cd "${APP_DIR}"
    MIX_ENV=prod mix ecto.migrate >> "${DEPLOY_LOG}" 2>&1
    log_success "Migrations completed"
}

step_deploy_assets() {
    log_info "Deploying and bundling assets..."
    cd "${APP_DIR}"
    MIX_ENV=prod mix assets.deploy >> "${DEPLOY_LOG}" 2>&1
    log_success "Assets deployed"
}

step_create_release() {
    log_info "Creating production release..."
    cd "${APP_DIR}"
    MIX_ENV=prod mix release --overwrite >> "${DEPLOY_LOG}" 2>&1
    log_success "Release created at _build/prod/rel/fittrack"
}

step_restart_service() {
    if [ "$SKIP_RESTART" = true ]; then
        log_warn "Skipping service restart"
        return
    fi
    
    log_info "Restarting fittrack service..."
    sudo systemctl restart fittrack
    sleep 2
    log_success "Service restarted"
}

step_verify() {
    log_info "Verifying deployment..."
    
    # Check service status
    if sudo systemctl is-active --quiet fittrack; then
        log_success "Service is running"
    else
        log_error "Service is not running"
        exit 1
    fi
    
    # Check migrations status
    cd "${APP_DIR}"
    local migration_status=$(MIX_ENV=prod mix ecto.migrations 2>/dev/null | grep "down" || true)
    if [ -z "$migration_status" ]; then
        log_success "All migrations applied"
    else
        log_warn "Some migrations are not applied"
    fi
    
    # Get service info
    log_info "Service status:"
    sudo systemctl status fittrack --no-pager | head -10 | sed 's/^/  /'
}

# Main execution
trap cleanup EXIT

echo "================================================================================"
echo "Fittrack Production Deployment"
echo "Started: $(date)"
echo "================================================================================"
echo ""

{
    parse_arguments "$@"
    
    step_git_pull
    step_load_environment
    step_get_dependencies
    step_compile
    step_migrate_database
    step_deploy_assets
    step_create_release
    step_restart_service
    step_verify
} 2>&1 | tee -a "${DEPLOY_LOG}"

echo ""
echo "================================================================================"
echo "Deployment log available at: ${DEPLOY_LOG}"
echo "================================================================================"

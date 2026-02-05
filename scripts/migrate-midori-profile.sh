#!/bin/bash
# Midori Browser Profile Migration Script
# Migrates user data from v11.6 (~/.midori) to v12.0 (~/.mozilla/midori)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
OLD_BASE_DIR="$HOME/.midori"
NEW_BASE_DIR="$HOME/.mozilla/midori"
MIDORI_BIN="${MIDORI_BIN:-/opt/midori/midori}"
CREATE_BACKUP="${CREATE_BACKUP:-yes}"

# Check if old Midori directory exists
if [ ! -d "$OLD_BASE_DIR" ]; then
    print_error "Old Midori directory not found: $OLD_BASE_DIR"
    print_info "Nothing to migrate."
    exit 0
fi

# Check if new Midori directory exists
if [ ! -d "$NEW_BASE_DIR" ]; then
    print_error "New Midori directory not found: $NEW_BASE_DIR"
    print_info "Please run Midori v12.0 at least once to create the profile."
    exit 1
fi

print_info "=== Midori Profile Migration ==="
print_info "From: $OLD_BASE_DIR"
print_info "To:   $NEW_BASE_DIR"
echo

# Kill running Midori instances
print_info "Checking for running Midori processes..."
if pgrep -f midori > /dev/null 2>&1; then
    print_warning "Midori is running. Attempting to close..."
    pkill -f midori || true
    sleep 2
    if pgrep -f midori > /dev/null 2>&1; then
        print_error "Failed to close Midori. Please close it manually and try again."
        exit 1
    fi
    print_success "Midori closed successfully"
fi

# Find old profile
print_info "Detecting old profile..."
if [ ! -f "$OLD_BASE_DIR/profiles.ini" ]; then
    print_error "profiles.ini not found in $OLD_BASE_DIR"
    exit 1
fi

OLD_PROFILE=$(grep "^Path=" "$OLD_BASE_DIR/profiles.ini" | grep "default-release" | head -n1 | cut -d= -f2)
if [ -z "$OLD_PROFILE" ]; then
    # Fallback: try to find any profile
    OLD_PROFILE=$(grep "^Path=" "$OLD_BASE_DIR/profiles.ini" | head -n1 | cut -d= -f2)
fi

if [ -z "$OLD_PROFILE" ]; then
    print_error "Could not detect old profile from profiles.ini"
    exit 1
fi

OLD_PROFILE_DIR="$OLD_BASE_DIR/$OLD_PROFILE"
if [ ! -d "$OLD_PROFILE_DIR" ]; then
    print_error "Old profile directory not found: $OLD_PROFILE_DIR"
    exit 1
fi

print_success "Found old profile: $OLD_PROFILE"
print_info "  Location: $OLD_PROFILE_DIR"

# Find new profile
print_info "Detecting new profile..."
if [ ! -f "$NEW_BASE_DIR/profiles.ini" ]; then
    print_error "profiles.ini not found in $NEW_BASE_DIR"
    exit 1
fi

# Try to find the install-specific profile
NEW_PROFILE=$(grep "^\[Install" "$NEW_BASE_DIR/profiles.ini" -A2 | grep "^Default=" | head -n1 | cut -d= -f2)
if [ -z "$NEW_PROFILE" ]; then
    # Fallback: find default-release profile
    NEW_PROFILE=$(grep "^Path=" "$NEW_BASE_DIR/profiles.ini" | grep "default-release" | head -n1 | cut -d= -f2)
fi

if [ -z "$NEW_PROFILE" ]; then
    print_error "Could not detect new profile from profiles.ini"
    exit 1
fi

NEW_PROFILE_DIR="$NEW_BASE_DIR/$NEW_PROFILE"
if [ ! -d "$NEW_PROFILE_DIR" ]; then
    print_error "New profile directory not found: $NEW_PROFILE_DIR"
    exit 1
fi

print_success "Found new profile: $NEW_PROFILE"
print_info "  Location: $NEW_PROFILE_DIR"
echo

# Show what will be migrated
print_info "Files to migrate:"
FILE_COUNT=$(find "$OLD_PROFILE_DIR" -type f 2>/dev/null | wc -l)
DIR_COUNT=$(find "$OLD_PROFILE_DIR" -type d 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$OLD_PROFILE_DIR" 2>/dev/null | cut -f1)
print_info "  Files: $FILE_COUNT"
print_info "  Directories: $DIR_COUNT"
print_info "  Total size: $TOTAL_SIZE"
echo

# Key files to migrate
print_info "Important data being migrated:"
[ -f "$OLD_PROFILE_DIR/places.sqlite" ] && print_info "  ✓ Bookmarks & History (places.sqlite)"
[ -f "$OLD_PROFILE_DIR/cookies.sqlite" ] && print_info "  ✓ Cookies (cookies.sqlite)"
[ -f "$OLD_PROFILE_DIR/favicons.sqlite" ] && print_info "  ✓ Favicons (favicons.sqlite)"
[ -f "$OLD_PROFILE_DIR/prefs.js" ] && print_info "  ✓ Preferences (prefs.js)"
[ -f "$OLD_PROFILE_DIR/key4.db" ] && print_info "  ✓ Passwords (key4.db)"
[ -d "$OLD_PROFILE_DIR/storage" ] && print_info "  ✓ Website storage"
print_info "  ✗ Extensions (will NOT be migrated - reinstall manually)"
echo

# Confirm
if [ "${AUTO_CONFIRM:-no}" != "yes" ]; then
    read -p "Continue with migration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Migration cancelled by user"
        exit 0
    fi
fi

# Backup new profile if requested
if [ "$CREATE_BACKUP" = "yes" ]; then
    BACKUP_DIR="${NEW_PROFILE_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
    print_info "Creating backup of new profile..."
    print_info "  Backup location: $BACKUP_DIR"
    cp -a "$NEW_PROFILE_DIR" "$BACKUP_DIR"
    print_success "Backup created"
fi

# Perform migration
print_info "Starting migration..."
print_info "Using rsync to merge profiles (excluding extensions)..."

# Use rsync to merge old data into new profile
# --ignore-existing: don't overwrite files that already exist in destination
# -a: archive mode (preserve permissions, timestamps, etc.)
# -v: verbose
# --exclude: skip extensions directory (old extensions may cause issues)
rsync -av --ignore-existing \
    --exclude 'extensions/' \
    --exclude 'browser-extension-data/' \
    --exclude 'extension-store/' \
    "$OLD_PROFILE_DIR/" "$NEW_PROFILE_DIR/"

print_success "Data migration completed"
print_info "Note: Extensions were NOT migrated - reinstall them manually"

# Update compatibility.ini
print_info "Updating compatibility information..."
if [ -f "$MIDORI_BIN" ]; then
    APP_INI="/opt/midori/application.ini"
    if [ -f "$APP_INI" ]; then
        VERSION=$(grep "^Version=" "$APP_INI" | cut -d= -f2)
        BUILD_ID=$(grep "^BuildID=" "$APP_INI" | cut -d= -f2)
        
        cat > "$NEW_PROFILE_DIR/compatibility.ini" << EOF
[Compatibility]
LastVersion=${VERSION}_${BUILD_ID}/${BUILD_ID}
LastOSABI=Linux_x86_64-gcc3
LastPlatformDir=/opt/midori
LastAppDir=/opt/midori/browser
EOF
        print_success "Updated compatibility.ini (Version: $VERSION, Build: $BUILD_ID)"
    else
        print_warning "Could not find application.ini, skipping compatibility.ini update"
    fi
else
    print_warning "Midori binary not found at $MIDORI_BIN, skipping compatibility.ini update"
fi

# Summary
echo
print_success "=== Migration Complete ==="
print_info "Summary:"
print_info "  Old profile: $OLD_PROFILE_DIR"
print_info "  New profile: $NEW_PROFILE_DIR"
[ "$CREATE_BACKUP" = "yes" ] && print_info "  Backup: $BACKUP_DIR"
echo
print_info "Next steps:"
print_info "  1. Launch Midori v12.0"
print_info "  2. Verify your bookmarks, history, and settings"
print_info "  3. If everything works, you can remove the old profile:"
print_info "     rm -rf $OLD_BASE_DIR"
echo
print_success "All done! 🎉"

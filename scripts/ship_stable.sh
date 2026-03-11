#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_YML="project.yml"
PBXPROJ="Tonica.xcodeproj/project.pbxproj"
CANDIDATE_WORKFLOW="build-candidate.yml"
RELEASE_WORKFLOW="release.yml"
VERIFY_SCRIPT="./scripts/verify_stable_release.sh"
STABLE_DMG_URL="https://github.com/artoshirei/Tonica/releases/latest/download/Tonica.dmg"
STABLE_APPCAST_URL="https://raw.githubusercontent.com/artoshirei/Tonica/main/docs/appcast.xml"

DRY_RUN=false
ASSUME_YES=false
NO_WAIT=false
MODE=""
REF="HEAD"
TAG=""
VERSION=""

usage() {
  cat <<'EOF'
Usage:
  ./scripts/ship_stable.sh [--dry-run] [--yes] [--no-wait] patch
  ./scripts/ship_stable.sh [--dry-run] [--yes] [--no-wait] minor
  ./scripts/ship_stable.sh [--dry-run] [--yes] [--no-wait] major
  ./scripts/ship_stable.sh [--dry-run] [--yes] [--no-wait] candidate [--ref <git-ref>]
  ./scripts/ship_stable.sh [--dry-run] [--yes] [--no-wait] republish --tag vX.Y.Z --version X.Y.Z
  ./scripts/ship_stable.sh --dry-run

Modes:
  candidate   Trigger Tonica's candidate workflow for an already-pushed commit
  patch       Bump patch version, build candidate, tag, and publish stable
  minor       Bump minor version, build candidate, tag, and publish stable
  major       Bump major version, build candidate, tag, and publish stable
  republish   Re-run Tonica's stable publish workflow for an existing tag/version

Flags:
  --dry-run   Print the planned actions without changing git or dispatching workflows
  --yes       Skip confirmation prompts
  --no-wait   Do not wait for the final workflow completion
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

note() {
  echo "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

run_cmd() {
  if $DRY_RUN; then
    printf '[dry-run]'
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    return 0
  fi

  "$@"
}

read_project_yml_value_from_stdin() {
  local key="$1"
  sed -n "s/^[[:space:]]*${key}:[[:space:]]*//p" | head -n 1
}

read_pbxproj_value_from_stdin() {
  local key="$1"
  sed -n "s/.*${key} = //p" | sed 's/;//' | sed 's/[[:space:]]//g' | head -n 1
}

read_project_yml_value_file() {
  local key="$1"
  read_project_yml_value_from_stdin "$key" < "$PROJECT_YML"
}

read_pbxproj_value_file() {
  local key="$1"
  read_pbxproj_value_from_stdin "$key" < "$PBXPROJ"
}

read_project_yml_value_ref() {
  local ref="$1"
  local key="$2"
  git show "${ref}:${PROJECT_YML}" | read_project_yml_value_from_stdin "$key"
}

read_pbxproj_value_ref() {
  local ref="$1"
  local key="$2"
  git show "${ref}:${PBXPROJ}" | read_pbxproj_value_from_stdin "$key"
}

assert_clean_tree() {
  [[ -z "$(git status --porcelain)" ]] || die "Working tree is dirty. Commit or stash changes before shipping."
}

assert_main_branch() {
  local branch
  branch="$(git branch --show-current)"
  [[ "$branch" == "main" ]] || die "Patch/minor/major releases must run from main. Current branch: ${branch:-detached}"
}

assert_runner_configured() {
  if ! gh variable get RELEASE_RUNNER_LABELS_JSON >/dev/null 2>&1; then
    die "Missing repo variable RELEASE_RUNNER_LABELS_JSON. Refusing to dispatch release workflows."
  fi
}

assert_worktree_sync() {
  local project_version project_build pbx_version pbx_build
  project_version="$(read_project_yml_value_file MARKETING_VERSION)"
  project_build="$(read_project_yml_value_file CURRENT_PROJECT_VERSION)"
  pbx_version="$(read_pbxproj_value_file MARKETING_VERSION)"
  pbx_build="$(read_pbxproj_value_file CURRENT_PROJECT_VERSION)"

  [[ "$project_version" == "$pbx_version" ]] || die "project.yml MARKETING_VERSION (${project_version}) does not match generated project (${pbx_version}). Run xcodegen generate first."
  [[ "$project_build" == "$pbx_build" ]] || die "project.yml CURRENT_PROJECT_VERSION (${project_build}) does not match generated project (${pbx_build}). Run xcodegen generate first."
}

assert_ref_sync() {
  local ref="$1"
  local project_version project_build pbx_version pbx_build
  project_version="$(read_project_yml_value_ref "$ref" MARKETING_VERSION)"
  project_build="$(read_project_yml_value_ref "$ref" CURRENT_PROJECT_VERSION)"
  pbx_version="$(read_pbxproj_value_ref "$ref" MARKETING_VERSION)"
  pbx_build="$(read_pbxproj_value_ref "$ref" CURRENT_PROJECT_VERSION)"

  [[ "$project_version" == "$pbx_version" ]] || die "${ref} has project.yml version ${project_version} but generated project version ${pbx_version}."
  [[ "$project_build" == "$pbx_build" ]] || die "${ref} has project.yml build ${project_build} but generated project build ${pbx_build}."
}

semver_parts() {
  local version="$1"
  local major minor patch extra
  IFS=. read -r major minor patch extra <<<"$version"
  [[ -n "${major:-}" && -n "${minor:-}" ]] || die "Unsupported version format: $version"
  [[ -z "${extra:-}" ]] || die "Unsupported version format: $version"
  patch="${patch:-0}"
  echo "$major $minor $patch"
}

next_version_for_mode() {
  local mode="$1"
  local version="$2"
  local major minor patch
  read -r major minor patch <<<"$(semver_parts "$version")"

  case "$mode" in
    patch)
      patch=$((patch + 1))
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    *)
      die "Unsupported release mode for version increment: $mode"
      ;;
  esac

  echo "${major}.${minor}.${patch}"
}

iso_from_epoch() {
  date -u -r "$1" +"%Y-%m-%dT%H:%M:%SZ"
}

extract_run_id_from_output() {
  sed -n 's#.*actions/runs/\([0-9][0-9]*\).*#\1#p' <<<"$1" | tail -n 1
}

find_run_id() {
  local workflow="$1"
  local event="$2"
  local after_epoch="$3"
  local head_sha="${4:-}"
  local after_iso run_id runs_json
  after_iso="$(iso_from_epoch "$after_epoch")"

  for _attempt in $(seq 1 30); do
    runs_json="$(gh run list --workflow "$workflow" --limit 30 --json databaseId,event,headSha,createdAt)"
    run_id="$(jq -r \
      --arg event "$event" \
      --arg after "$after_iso" \
      --arg head "$head_sha" '
        map(select(.event == $event and .createdAt >= $after and ($head == "" or .headSha == $head)))
        | sort_by(.createdAt)
        | last
        | .databaseId // empty
      ' <<<"$runs_json")"
    if [[ -n "$run_id" ]]; then
      echo "$run_id"
      return 0
    fi
    sleep 2
  done

  return 1
}

wait_for_run() {
  local run_id="$1"
  note "Watching workflow run ${run_id}..."
  gh run watch "$run_id" --exit-status
}

confirm_or_exit() {
  local prompt="$1"
  if $DRY_RUN || $ASSUME_YES; then
    return 0
  fi

  printf "%s [y/N] " "$prompt"
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || die "Aborted."
}

ensure_origin_contains_commit() {
  local sha="$1"
  git fetch origin --tags --quiet
  git branch -r --contains "$sha" | grep -q 'origin/' || die "Commit ${sha} is not reachable from any fetched origin branch. Push it first."
}

ensure_remote_tag_absent() {
  local tag="$1"
  git fetch origin --tags --quiet
  if git rev-parse --verify "refs/tags/${tag}" >/dev/null 2>&1 || git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
    die "Tag ${tag} already exists on origin."
  fi
}

ensure_remote_tag_present() {
  local tag="$1"
  git fetch origin --tags --quiet
  git rev-parse --verify "refs/tags/${tag}^{commit}" >/dev/null 2>&1 || die "Tag ${tag} does not exist locally after fetching origin tags."
}

update_project_versions() {
  local new_version="$1"
  local new_build="$2"

  perl -0pi -e "s/(MARKETING_VERSION:\\s*)[^\n]+/\${1}${new_version}/" "$PROJECT_YML"
  perl -0pi -e "s/(CURRENT_PROJECT_VERSION:\\s*)[^\n]+/\${1}${new_build}/" "$PROJECT_YML"
}

dispatch_candidate_workflow() {
  local commit_sha="$1"
  local version="$2"
  local release_tag="$3"
  local before_epoch output run_id
  before_epoch="$(date -u +%s)"

  if $DRY_RUN; then
    note "[dry-run] would dispatch ${CANDIDATE_WORKFLOW} with commit_sha=${commit_sha} version=${version} release_tag=${release_tag}" >&2
    return 0
  fi

  output="$(gh workflow run "$CANDIDATE_WORKFLOW" \
    -f commit_sha="$commit_sha" \
    -f version="$version" \
    -f release_tag="$release_tag" 2>&1)" || {
      printf '%s\n' "$output" >&2
      return 1
    }

  printf '%s\n' "$output" >&2
  run_id="$(extract_run_id_from_output "$output")"
  if [[ -z "$run_id" ]]; then
    run_id="$(find_run_id "$CANDIDATE_WORKFLOW" workflow_dispatch "$before_epoch" "")" \
      || die "Dispatched ${CANDIDATE_WORKFLOW}, but could not resolve the run id."
  fi

  echo "$run_id"
}

dispatch_release_workflow() {
  local release_tag="$1"
  local version="$2"
  local commit_sha="$3"
  local before_epoch output run_id
  before_epoch="$(date -u +%s)"

  if $DRY_RUN; then
    note "[dry-run] would dispatch ${RELEASE_WORKFLOW} with release_tag=${release_tag} version=${version} commit_sha=${commit_sha}" >&2
    return 0
  fi

  output="$(gh workflow run "$RELEASE_WORKFLOW" \
    -f release_tag="$release_tag" \
    -f version="$version" \
    -f commit_sha="$commit_sha" 2>&1)" || {
      printf '%s\n' "$output" >&2
      return 1
    }

  printf '%s\n' "$output" >&2
  run_id="$(extract_run_id_from_output "$output")"
  if [[ -z "$run_id" ]]; then
    run_id="$(find_run_id "$RELEASE_WORKFLOW" workflow_dispatch "$before_epoch" "")" \
      || die "Dispatched ${RELEASE_WORKFLOW}, but could not resolve the run id."
  fi

  echo "$run_id"
}

wait_for_tag_release_run() {
  local commit_sha="$1"
  local after_epoch="$2"
  local run_id
  run_id="$(find_run_id "$RELEASE_WORKFLOW" push "$after_epoch" "$commit_sha")" \
    || die "Could not find the tag-push release workflow for ${commit_sha}."
  echo "$run_id"
}

print_preview() {
  local current_version current_build patch_version minor_version major_version
  current_version="$(read_project_yml_value_file MARKETING_VERSION)"
  current_build="$(read_project_yml_value_file CURRENT_PROJECT_VERSION)"
  patch_version="$(next_version_for_mode patch "$current_version")"
  minor_version="$(next_version_for_mode minor "$current_version")"
  major_version="$(next_version_for_mode major "$current_version")"

  cat <<EOF
Tonica release preview

Current version: ${current_version}
Current build:   ${current_build}

Next patch: ${patch_version} (build $((current_build + 1)))
Next minor: ${minor_version} (build $((current_build + 1)))
Next major: ${major_version} (build $((current_build + 1)))

Stable DMG URL: ${STABLE_DMG_URL}
Stable appcast URL: ${STABLE_APPCAST_URL}
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --yes)
        ASSUME_YES=true
        shift
        ;;
      --no-wait)
        NO_WAIT=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      candidate|patch|minor|major|republish)
        MODE="$1"
        shift
        break
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  if [[ -z "$MODE" ]]; then
    if $DRY_RUN; then
      return 0
    fi
    usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --yes)
        ASSUME_YES=true
        shift
        ;;
      --no-wait)
        NO_WAIT=true
        shift
        ;;
      --ref)
        [[ $# -ge 2 ]] || die "Missing value for --ref"
        REF="$2"
        shift 2
        ;;
      --tag)
        [[ $# -ge 2 ]] || die "Missing value for --tag"
        TAG="$2"
        shift 2
        ;;
      --version)
        [[ $# -ge 2 ]] || die "Missing value for --version"
        VERSION="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

validate_mode_args() {
  case "$MODE" in
    candidate)
      [[ -z "$TAG" ]] || die "--tag is not used with candidate mode"
      [[ -z "$VERSION" ]] || die "--version is not used with candidate mode"
      ;;
    patch|minor|major)
      [[ -z "$TAG" ]] || die "--tag is not used with ${MODE} mode"
      [[ -z "$VERSION" ]] || die "--version is not used with ${MODE} mode"
      [[ "$REF" == "HEAD" ]] || die "--ref is not used with ${MODE} mode"
      ;;
    republish)
      [[ "$REF" == "HEAD" ]] || die "--ref is not used with republish mode"
      ;;
  esac
}

run_patch_minor_major() {
  local current_version current_build next_version next_build release_tag commit_sha
  current_version="$(read_project_yml_value_file MARKETING_VERSION)"
  current_build="$(read_project_yml_value_file CURRENT_PROJECT_VERSION)"
  next_version="$(next_version_for_mode "$MODE" "$current_version")"
  next_build=$((current_build + 1))
  release_tag="v${next_version}"

  note "Mode: ${MODE}"
  note "Version: ${current_version} -> ${next_version}"
  note "Build: ${current_build} -> ${next_build}"
  note "Release tag: ${release_tag}"

  confirm_or_exit "Proceed with ${MODE} release ${release_tag}?"

  if $DRY_RUN; then
    note "[dry-run] would update ${PROJECT_YML}"
    note "[dry-run] would run xcodegen generate"
    note "[dry-run] would commit project.yml and generated project changes"
    note "[dry-run] would push main"
    note "[dry-run] would dispatch ${CANDIDATE_WORKFLOW}"
    note "[dry-run] would create and push tag ${release_tag} after candidate success"
    note "[dry-run] would watch ${RELEASE_WORKFLOW} and verify stable URLs"
    return 0
  fi

  require_cmd xcodegen
  assert_main_branch
  assert_worktree_sync
  ensure_remote_tag_absent "$release_tag"

  update_project_versions "$next_version" "$next_build"
  xcodegen generate

  git add "$PROJECT_YML" "$PBXPROJ"
  git diff --cached --quiet && die "Release bump did not produce any staged changes."
  git commit -m "Release ${release_tag}"

  commit_sha="$(git rev-parse HEAD)"
  git push origin main

  local candidate_run_id
  candidate_run_id="$(dispatch_candidate_workflow "$commit_sha" "$next_version" "$release_tag")"
  note "Candidate run id: ${candidate_run_id}"
  wait_for_run "$candidate_run_id"

  local before_tag_push_epoch release_run_id
  before_tag_push_epoch="$(date -u +%s)"
  git tag "$release_tag" "$commit_sha"
  git push origin "$release_tag"

  if $NO_WAIT; then
    note "Tag pushed. Not waiting for ${RELEASE_WORKFLOW} because --no-wait was set."
    return 0
  fi

  release_run_id="$(wait_for_tag_release_run "$commit_sha" "$before_tag_push_epoch")"
  note "Release run id: ${release_run_id}"
  wait_for_run "$release_run_id"
  "$VERIFY_SCRIPT" --tag "$release_tag" --version "$next_version"
}

run_candidate() {
  local commit_sha version build release_tag candidate_run_id
  commit_sha="$(git rev-parse "${REF}^{commit}")"
  assert_ref_sync "$commit_sha"
  ensure_origin_contains_commit "$commit_sha"

  version="$(read_project_yml_value_ref "$commit_sha" MARKETING_VERSION)"
  build="$(read_project_yml_value_ref "$commit_sha" CURRENT_PROJECT_VERSION)"
  release_tag="v${version}"

  note "Mode: candidate"
  note "Ref: ${REF}"
  note "Commit: ${commit_sha}"
  note "Version: ${version}"
  note "Build: ${build}"
  note "Release tag: ${release_tag}"

  confirm_or_exit "Dispatch candidate build for ${commit_sha}?"

  candidate_run_id="$(dispatch_candidate_workflow "$commit_sha" "$version" "$release_tag")"
  if [[ -n "${candidate_run_id:-}" ]]; then
    note "Candidate run id: ${candidate_run_id}"
  fi

  if ! $DRY_RUN && ! $NO_WAIT; then
    wait_for_run "$candidate_run_id"
  fi
}

run_republish() {
  [[ -n "$TAG" ]] || die "republish requires --tag vX.Y.Z"
  [[ -n "$VERSION" ]] || die "republish requires --version X.Y.Z"
  [[ "$TAG" == "v$VERSION" ]] || die "--tag must match --version exactly"

  ensure_remote_tag_present "$TAG"
  assert_ref_sync "$TAG"

  local tag_version tag_build commit_sha release_run_id
  tag_version="$(read_project_yml_value_ref "$TAG" MARKETING_VERSION)"
  tag_build="$(read_project_yml_value_ref "$TAG" CURRENT_PROJECT_VERSION)"
  [[ "$tag_version" == "$VERSION" ]] || die "Tag ${TAG} points to version ${tag_version}, not ${VERSION}."
  commit_sha="$(git rev-parse "${TAG}^{commit}")"

  note "Mode: republish"
  note "Tag: ${TAG}"
  note "Version: ${VERSION}"
  note "Build: ${tag_build}"
  note "Commit: ${commit_sha}"

  confirm_or_exit "Republish ${TAG} without bumping the version?"

  release_run_id="$(dispatch_release_workflow "$TAG" "$VERSION" "$commit_sha")"
  if [[ -n "${release_run_id:-}" ]]; then
    note "Release run id: ${release_run_id}"
  fi

  if ! $DRY_RUN && ! $NO_WAIT; then
    wait_for_run "$release_run_id"
    "$VERIFY_SCRIPT" --tag "$TAG" --version "$VERSION"
  fi
}

main() {
  parse_args "$@"
  validate_mode_args

  require_cmd git
  require_cmd gh
  require_cmd jq
  require_cmd curl

  assert_clean_tree
  assert_runner_configured
  git fetch origin --tags --quiet

  if [[ -z "$MODE" ]]; then
    assert_worktree_sync
    print_preview
    exit 0
  fi

  case "$MODE" in
    patch|minor|major)
      run_patch_minor_major
      ;;
    candidate)
      run_candidate
      ;;
    republish)
      run_republish
      ;;
    *)
      die "Unsupported mode: $MODE"
      ;;
  esac
}

main "$@"

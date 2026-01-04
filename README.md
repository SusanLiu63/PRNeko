# PRNeko

A cute menu bar companion that monitors your GitHub pull requests. Your PR status, visualized as an animated cat.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Menu bar app** - Lives in your menu bar, not the dock
- **PR monitoring** - Tracks PRs you authored and PRs awaiting your review
- **Animated cat** - Shows different moods based on your PR status:
  - Idle/relaxed when everything is good
  - Anxious when PRs are blocked
  - Excited when PRs are ready to merge
  - Hungry when reviews are waiting for you
- **GitHub OAuth** - Secure device flow authentication
- **Auto-refresh** - Polls GitHub every 3 minutes

## Installation

### Build from source

```bash
git clone https://github.com/yourusername/PRNeko.git
cd PRNeko
swift build
```

### Create .app bundle

```bash
./scripts/build-release.sh
open PRNeko.app
```

## Usage

1. Click the paw icon in your menu bar
2. Log in with GitHub (uses secure device flow)
3. Your PRs will appear organized by status:
   - **Pending Reviews** - PRs waiting for your review
   - **Waiting for Review** - Your PRs awaiting review from others
   - **Merge Ready** - Approved and ready to merge
   - **Blocked** - PRs with failing checks or requested changes

## Requirements

- macOS 13.0 or later
- GitHub account

## Development

```bash
# Build and run
swift build && .build/debug/PRNeko

# Build release
swift build -c release
```

## License

MIT

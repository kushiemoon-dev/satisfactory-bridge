# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-13

### Added
- Initial public release
- GET `/status` endpoint for health checks
- POST `/command` endpoint for pushing commands to the game
- GET `/command` endpoint for game to poll commands (FIFO queue)
- GET `/queue` endpoint to view pending commands (non-destructive)
- DELETE `/queue` endpoint to clear all pending commands
- POST `/response` endpoint for game to report command results
- GET `/response` endpoint for game to report results (Linux server workaround)
- GET `/responses` endpoint to retrieve all responses (last 100)
- API key authentication via header or query parameter
- Lua bridge client library for FicsIt-Networks
- LEXIS factory control script (v6.0) with comprehensive command handling
- Log parser with health monitoring
- Alpine Linux init script for service management
- MIT License
- Comprehensive documentation and security guidelines

### Security
- API key masking in server logs (only shows last 4 characters)
- Required API key environment variable (no weak defaults)
- Security best practices documentation

---

[1.0.0]: https://github.com/kushie/satisfactory-bridge/releases/tag/v1.0.0

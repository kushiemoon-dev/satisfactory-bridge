# Contributing to Satisfactory Bridge

Thank you for your interest in contributing to Satisfactory Bridge! This document provides guidelines and instructions for contributing.

## Development Environment Setup

### Prerequisites

- Go 1.22 or higher
- Git
- (Optional) Satisfactory with FicsIt-Networks mod for testing

### Local Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/kushie/satisfactory-bridge.git
   cd satisfactory-bridge
   ```

2. **Build the bridge server**
   ```bash
   go build -o bridge main.go
   ```

3. **Build the log parser** (optional)
   ```bash
   cd parser
   go build
   cd ..
   ```

4. **Run locally**
   ```bash
   export BRIDGE_API_KEY="test-key-for-development"
   export BRIDGE_PORT=":8080"
   ./bridge
   ```

## Code Style Guidelines

### Go Code

- Follow standard Go formatting (`go fmt`)
- Use meaningful variable and function names
- Add comments for exported functions and types
- Keep functions focused and concise
- Handle errors explicitly

### Lua Scripts

- Use descriptive variable names
- Add comments for complex logic
- Follow existing indentation style (4 spaces)
- Test scripts in FicsIt-Networks before submitting

### Commit Messages

Follow the conventional commits format:

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat: add DELETE /queue endpoint for clearing commands

fix: handle nil pointer in command polling

docs: update API endpoint documentation
```

## Pull Request Process

1. **Fork the repository** and create a new branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clean, well-documented code
   - Add tests if applicable
   - Update documentation as needed

3. **Test your changes**
   ```bash
   # Build and run the bridge
   go build -o bridge main.go
   export BRIDGE_API_KEY="test-key"
   ./bridge

   # In another terminal, test the endpoints
   curl http://localhost:8080/status
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**
   - Provide a clear title and description
   - Reference any related issues
   - Include screenshots for UI changes
   - List any breaking changes

### Pull Request Checklist

- [ ] Code follows the project's style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings or errors
- [ ] Tested locally
- [ ] Commit messages follow conventional format

## Testing

### Manual Testing

Test the core functionality:

1. **Start the bridge server**
   ```bash
   export BRIDGE_API_KEY="test-key"
   ./bridge
   ```

2. **Test command posting**
   ```bash
   curl -X POST http://localhost:8080/command \
     -H "X-API-Key: test-key" \
     -H "Content-Type: application/json" \
     -d '{"action": "ping"}'
   ```

3. **Test command polling**
   ```bash
   curl -H "X-API-Key: test-key" http://localhost:8080/command
   ```

4. **Test response submission**
   ```bash
   curl -X POST http://localhost:8080/response \
     -H "X-API-Key: test-key" \
     -H "Content-Type: application/json" \
     -d '{"command_id": "123", "status": "success"}'
   ```

### Integration Testing

If you have access to Satisfactory with FicsIt-Networks:

1. Set up the Lua client script on an in-game computer
2. Configure it to point to your local bridge
3. Send commands through the bridge
4. Verify the game executes them correctly

## Reporting Bugs

When reporting bugs, please include:

1. **Description**: Clear description of the issue
2. **Steps to Reproduce**: Detailed steps to reproduce the behavior
3. **Expected Behavior**: What you expected to happen
4. **Actual Behavior**: What actually happened
5. **Environment**:
   - OS (Linux, Windows, macOS)
   - Go version (`go version`)
   - FicsIt-Networks version (if applicable)
6. **Logs**: Relevant log output or error messages
7. **Screenshots**: If applicable

## Feature Requests

Feature requests are welcome! Please:

1. Check if the feature has already been requested
2. Provide a clear use case
3. Explain the expected behavior
4. Consider implementation complexity

## Questions and Support

- **Issues**: For bug reports and feature requests
- **Discussions**: For questions and general discussion (if enabled)

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Personal or political attacks
- Public or private harassment
- Publishing others' private information

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be recognized in the project documentation. Significant contributions may be highlighted in release notes.

---

Thank you for contributing to Satisfactory Bridge!

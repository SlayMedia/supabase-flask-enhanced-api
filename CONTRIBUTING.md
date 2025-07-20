# Contributing to Supabase Flask Enhanced API

We welcome contributions to the Supabase Flask Enhanced API project! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Code Style](#code-style)
- [Documentation](#documentation)

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please be respectful and constructive in all interactions.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/supabase-flask-enhanced-api.git
   cd supabase-flask-enhanced-api
   ```
3. **Set up the development environment** (see Development Setup below)

## Development Setup

### Prerequisites
- Python 3.8 or higher
- PostgreSQL 12+ (via Supabase)
- Redis (optional, for caching)
- Git

### Environment Setup

1. **Create a virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   pip install -r requirements-dev.txt  # Development dependencies
   ```

3. **Set up environment variables:**
   ```bash
   cp backend/.env.example backend/.env
   # Edit backend/.env with your Supabase credentials
   ```

4. **Set up the database:**
   ```bash
   cd supabase-project
   python create_telemetry_schema.py
   ```

5. **Verify the setup:**
   ```bash
   python verify_telemetry_pipeline.py
   ```

## Making Changes

### Branch Naming
Use descriptive branch names:
- `feature/add-websocket-support`
- `fix/batch-processing-memory-leak`
- `docs/update-api-documentation`
- `perf/optimize-database-queries`

### Commit Messages
Follow conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(api): add WebSocket support for real-time streaming

fix(storage): resolve memory leak in batch processing

docs(readme): update installation instructions
```

## Testing

### Running Tests

1. **Unit tests:**
   ```bash
   python -m pytest tests/unit/
   ```

2. **Integration tests:**
   ```bash
   python -m pytest tests/integration/
   ```

3. **End-to-end tests:**
   ```bash
   python verify_telemetry_pipeline.py
   ```

4. **Performance tests:**
   ```bash
   python -m pytest tests/performance/
   ```

### Writing Tests

- Write tests for all new features
- Ensure tests cover edge cases
- Use descriptive test names
- Mock external dependencies
- Aim for high test coverage

### Test Structure
```
tests/
├── unit/
│   ├── test_telemetry_parser.py
│   ├── test_supabase_client.py
│   └── test_storage.py
├── integration/
│   ├── test_api_endpoints.py
│   └── test_database_operations.py
└── performance/
    └── test_batch_processing.py
```

## Code Style

### Python Style Guide
- Follow [PEP 8](https://pep8.org/)
- Use [Black](https://black.readthedocs.io/) for code formatting
- Use [isort](https://pycqa.github.io/isort/) for import sorting
- Use [flake8](https://flake8.pycqa.org/) for linting

### Code Formatting
```bash
# Format code
black backend/

# Sort imports
isort backend/

# Lint code
flake8 backend/
```

### Type Hints
Use type hints for all function parameters and return values:
```python
def parse_telemetry_line(self, raw_data: str) -> dict:
    """Parse a telemetry line in key:value format"""
    # Implementation
```

### Documentation Strings
Use Google-style docstrings:
```python
def add_telemetry_data(self, telemetry_data: Dict[str, Any]) -> bool:
    """Add telemetry data to pending batch.
    
    Args:
        telemetry_data: Dictionary containing telemetry data
        
    Returns:
        True if data was added successfully, False otherwise
        
    Raises:
        ValueError: If telemetry_data is invalid
    """
```

## Documentation

### API Documentation
- Document all API endpoints
- Include request/response examples
- Specify error codes and messages
- Update OpenAPI/Swagger specs

### Code Documentation
- Write clear docstrings for all functions and classes
- Include usage examples
- Document complex algorithms
- Explain design decisions

### README Updates
- Update README.md for new features
- Include configuration changes
- Update installation instructions
- Add troubleshooting information

## Submitting Changes

### Pull Request Process

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes and commit:**
   ```bash
   git add .
   git commit -m "feat(scope): your descriptive message"
   ```

3. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create a Pull Request** on GitHub

### Pull Request Guidelines

- **Title**: Use a descriptive title
- **Description**: Explain what changes you made and why
- **Testing**: Describe how you tested your changes
- **Documentation**: Update relevant documentation
- **Breaking Changes**: Clearly mark any breaking changes

### Pull Request Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

## Review Process

1. **Automated Checks**: All CI checks must pass
2. **Code Review**: At least one maintainer review required
3. **Testing**: All tests must pass
4. **Documentation**: Documentation must be updated
5. **Approval**: Maintainer approval required for merge

## Release Process

1. **Version Bump**: Update version numbers
2. **Changelog**: Update CHANGELOG.md
3. **Testing**: Run full test suite
4. **Documentation**: Update documentation
5. **Tag**: Create git tag for release
6. **Deploy**: Deploy to production

## Getting Help

- **Issues**: Create an issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check the README and docs/ directory
- **Contact**: Reach out to maintainers

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing to the Supabase Flask Enhanced API project!
# Quality Assurance — nem.infrastructure

## Testing Strategy

`nem.infrastructure` provides shared Docker Compose configurations, reverse proxy setup, and infrastructure tooling for the nem.* platform. Quality assurance follows the nem.* testing pyramid with unit, integration, and end-to-end test layers.

### Test Pyramid

| Layer | Framework | Focus |
|-------|-----------|-------|
| Unit | xUnit v3 + NSubstitute | Domain logic, value objects, business rules |
| Integration | WebApplicationFactory + Testcontainers | API endpoints, persistence, messaging |
| End-to-End | Playwright (if UI) / HTTP client | Full workflow validation |

### Running Tests

```bash
dotnet test nem.infrastructure.slnx
```

For specific test categories:

```bash
dotnet test nem.infrastructure.slnx --filter "Category=Unit"
dotnet test nem.infrastructure.slnx --filter "Category=Integration"
```

## Test Infrastructure

### Mocking and Fakes

- **NSubstitute**: Interface mocking for unit tests
- **WireMock**: HTTP service simulation for integration tests
- **Testcontainers**: Disposable PostgreSQL and RabbitMQ for integration tests

### Test Data Management

- **Respawn**: Database reset between integration tests
- **Builder pattern**: Fluent test data builders for domain objects
- **Fixtures**: Shared test fixtures for common setup

## Quality Gates

### CI Pipeline Checks

All pull requests must pass:

1. **Build**: Solution compiles without warnings
2. **Unit tests**: All unit tests pass
3. **Integration tests**: All integration tests pass with Testcontainers
4. **Code analysis**: No new analyzer warnings
5. **Documentation**: Structure validation and stub-content scan

### Code Review Standards

- All changes require at least one reviewer approval
- Security-sensitive changes require security team review
- Architecture changes require architect approval

## Coverage and Metrics

### Current Coverage Targets

| Metric | Target | Enforcement |
|--------|--------|-------------|
| Line coverage | >80% for domain | CI gate |
| Branch coverage | >70% for domain | Advisory |
| Mutation score | Monitored | Quarterly review |

### Quality Metrics

- **Build success rate**: Tracked per branch
- **Test execution time**: Monitored for regression
- **Flaky test rate**: Flagged for investigation

## Conventions

### Test Naming

Tests follow the `MethodName_Scenario_ExpectedBehavior` convention:

```csharp
public class MyServiceTests
{
    [Fact]
    public void ProcessRequest_ValidInput_ReturnsSuccess() { }
    
    [Fact]
    public void ProcessRequest_InvalidInput_ThrowsValidationException() { }
}
```

### Assertion Library

Tests use **AwesomeAssertions** (formerly FluentAssertions) for readable assertions:

```csharp
result.Should().NotBeNull();
result.Status.Should().Be(Status.Active);
```

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — System design overview

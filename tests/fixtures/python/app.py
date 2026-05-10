# Clean Python fixture — used by CI integration tests (sast-python.yml)
# Must remain vulnerability-free so the SAST job passes with exit-code: 1


def add(a: int, b: int) -> int:
    return a + b


def greet(name: str) -> str:
    return f"Hello, {name}!"

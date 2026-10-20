
#include <cstdio>
#include <exception>

int main() {
  try {
    printf("Hello World!\n");
  } catch (const std::exception &e) {
    printf("Error: %s\n", e.what());
  }
}

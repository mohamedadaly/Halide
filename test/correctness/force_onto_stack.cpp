#include "Halide.h"
using namespace Halide;


void *my_malloc(void *user_context, size_t x) {
    printf("There was not supposed to be a heap allocation\n");
    exit(-1);
    return nullptr;
}

void my_free(void *user_context, void *ptr) {
}


bool errored = false;
void my_error(void *user_context, const char* msg) {
    errored = true;
    char expected[] = "Bounds given for f in x (from 0 to 7) do not cover required region (from 0 to 9)";
    if (strncmp(expected, msg, sizeof(expected)-1)) {
        printf("Unexpected error: '%s'\n", msg);
        exit(-1);
    }
}


int main(int argc, char **argv) {

    Func f("f"), g;
    Var x("x"), xo, xi;

    Param<int> p;

    f(x) = x;
    g(x) = f(x);
    g.split(x, xo, xi, p);

    // We need p elements of f per split of g. This could create a
    // dynamic allocation. Instead we'll assert that 8 is enough, so
    // that f can go on the stack and be entirely vectorized.
    f.compute_at(g, xo).bound(x, Expr(), 8).vectorize(x);

    // Check there's no malloc when the bound is good
    g.set_custom_allocator(&my_malloc, &my_free);
    p.set(5);
    g.realize(20);
    g.set_custom_allocator(nullptr, nullptr);

    // Check there was an assertion failure of the appropriate type when the bound is violated
    g.set_error_handler(&my_error);
    p.set(10);
    g.realize(20);


    if (!errored) {
        printf("There was supposed to be an error\n");
        return -1;
    }

    printf("Success!\n");
    return 0;

}

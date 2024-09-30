module econia::red_black_map {
    enum Color {
        Red,
        Black
    }

    struct Node<V> {
        key: u256,
        value: V,
        color: Color
    }
}

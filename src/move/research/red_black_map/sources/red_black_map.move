module econia::red_black_map {

    use std::vector;

    enum Color has copy, drop {
        Red,
        Black
    }

    enum Pointer has copy, drop {
        Index(u64),
        Null
    }

    struct Node<V> has drop {
        key: u256,
        value: V,
        color: Color,
        parent: Pointer,
        left: Pointer,
        right: Pointer
    }

    struct Map<V> has drop {
        root: Pointer,
        nodes: vector<Node<V>>
    }

    public fun new<V>(): Map<V> {
        Map { root: Pointer::Null, nodes: vector::empty() }
    }

    public fun insert<V: drop>(self: &mut Map<V>, key: u256, value: V) {
        match(self.root) {
            Null => {
                self.nodes.push_back(
                    Node {
                        key: key,
                        value: value,
                        color: Color::Black,
                        parent: Pointer::Null,
                        left: Pointer::Null,
                        right: Pointer::Null
                    }
                );
                self.root = Pointer::Index(0);
            }
            _ => {}
        }
    }

    public fun length<V>(self: &Map<V>): u64 {
        self.nodes.length()
    }

    #[test]
    fun test_insert_length() {
        let map = new();
        assert!(map.length() == 0);
        map.insert(1, 1);
        assert!(map.length() == 1);
    }
}

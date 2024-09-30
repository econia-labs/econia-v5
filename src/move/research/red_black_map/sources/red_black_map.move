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

    enum Side has copy, drop {
        Left,
        Right,
        Null
    }

    enum SearchResult has copy, drop {
        Found {
            node: Pointer,
            side_as_child: Side
        },
        NotFound {
            prospective_parent: Pointer,
            prospective_side_as_child: Side
        }
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

    /*
        public fun contains<V>(self: &Map<V>, key: u256): bool {
            match (self.search(key)) {
                Found { node: _, side_as_child: _ } => true,
                NotFound { prospective_parent: _, prospective_side_as_child: _ } => false
            }
        }
    */

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

    fun search<V: drop>(self: &Map<V>, key: u256): SearchResult {
        let side_as_child = Side::Null;
        match(self.root) {
            Null => {
                return SearchResult::NotFound {
                    prospective_parent: Pointer::Null,
                    prospective_side_as_child: side_as_child
                }
            }
            Index(index) => {
                loop {
                    let node = &self.nodes[index];
                    if (key < node.key) {
                        match(node.left) {
                            Index(next_index) => {
                                index = next_index;
                                side_as_child = Side::Left;
                            }
                            Null => {
                                return SearchResult::NotFound {
                                    prospective_parent: Pointer::Index(index),
                                    prospective_side_as_child: Side::Left
                                };
                            }
                        }
                    } else if (key > node.key) {
                        match(node.right) {
                            Index(next_index) => {
                                index = next_index;
                                side_as_child = Side::Right;
                            }
                            Null => {
                                return SearchResult::NotFound {
                                    prospective_parent: Pointer::Index(index),
                                    prospective_side_as_child: Side::Right
                                };
                            }
                        }
                    } else {
                        return SearchResult::Found {
                            node: Pointer::Index(index),
                            side_as_child: side_as_child
                        };
                    }
                }
            }
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

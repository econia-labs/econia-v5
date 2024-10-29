// cspell:word rebalance
module red_black_map::red_black_map {

    use std::vector;

    /// The key already exists in the map.
    const E_KEY_EXISTS: u64 = 0;

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

    /// Get child direction (side of node as child to parent) of non-root node at `node_index`.
    inline fun child_direction<V: drop>(self: &Map<V>, node_index: u64): Side {
        let Index(parent_index) = self.nodes[node_index].parent;
        if (self.nodes[parent_index].left == Pointer::Index(node_index)) Side::Left
        else Side::Right
    }

    /// Rotate subtree at `parent_index` in given `direction`, per Wikipedia implementation guide.
    inline fun rotate<V: drop>(
        self: &mut Map<V>, parent_index: u64, direction: Side
    ): u64 {
        let parent_ref = &self.nodes[parent_index];
        // RBnode* G = P->parent;
        let grandparent_pointer = parent_ref.parent;
        // RBnode* S = P->child[1-dir];
        let Index(subtree_index) = parent_ref.child_on_opposite_side(direction);
        // C = S->child[dir];
        let child_pointer = self.nodes[subtree_index].child_on_side(direction);
        // P->child[1-dir] = C;
        *self.nodes[parent_index].child_on_opposite_side_mut(direction) = child_pointer;
        // if (C != NIL) C->parent = P;
        match(child_pointer) {
            Index(child_index) => {
                self.nodes[child_index].parent = Pointer::Index(parent_index);
            }
        };
        // S->child[  dir] = P;
        *self.nodes[subtree_index].child_on_side_mut(direction) = Pointer::Index(
            parent_index
        );
        // P->parent = S;
        self.nodes[parent_index].parent = Pointer::Index(subtree_index);
        // S->parent = G;
        self.nodes[subtree_index].parent = grandparent_pointer;
        match(grandparent_pointer) {
            Index(grandparent_index) => {
                // G->child[ P == G->right ? RIGHT : LEFT ] = S;
                let grandparent_ref_mut = &mut self.nodes[grandparent_index];
                if (grandparent_ref_mut.right == Pointer::Index(parent_index)) {
                    grandparent_ref_mut.right = Pointer::Index(subtree_index);
                } else {
                    grandparent_ref_mut.left = Pointer::Index(subtree_index);
                }
            },
            Null => {
                // T->root = S;
                self.root = Pointer::Index(subtree_index);
            }
        };
        subtree_index
    }

    inline fun child_on_side<V: drop>(self: &Node<V>, side: Side): Pointer {
        if (side is Side::Left) self.left else self.right
    }

    inline fun child_on_side_mut<V: drop>(self: &mut Node<V>, side: Side): &mut Pointer {
        if (side is Side::Left) &mut self.left else &mut self.right
    }

    inline fun child_on_opposite_side<V: drop>(self: &Node<V>, side: Side): Pointer {
        if (side is Side::Left) self.right else self.left
    }

    inline fun child_on_opposite_side_mut<V: drop>(
        self: &mut Node<V>, side: Side
    ): &mut Pointer {
        if (side is Side::Left) &mut self.right else &mut self.left
    }

    public fun new<V>(): Map<V> {
        Map { root: Pointer::Null, nodes: vector::empty() }
    }

    public fun contains<V: drop>(self: &Map<V>, key: u256): bool {
        if (self.search(key) is SearchResult::Found) true else false
    }

    public fun insert<V: drop>(self: &mut Map<V>, key: u256, value: V) {

        // Find where new node should exist in the tree.
        let search_result = self.search(key);
        assert!(search_result is SearchResult::NotFound, E_KEY_EXISTS);
        let SearchResult::NotFound { prospective_parent, prospective_side_as_child } =
            search_result;

        // Insert black node at root if tree is empty, else red node as a leaf.
        let color =
            match(prospective_parent) {
                Null => {
                    self.root = Pointer::Index(0);
                    Color::Black
                },
                Index(parent_index) => {
                    let new_node_pointer = Pointer::Index(self.nodes.length());
                    let parent_ref_mut = &mut self.nodes[parent_index];
                    if (prospective_side_as_child is Side::Left) {
                        parent_ref_mut.left = new_node_pointer;
                    } else {
                        parent_ref_mut.right = new_node_pointer;
                    };
                    Color::Red
                }
            };
        self.nodes.push_back(
            Node {
                key,
                value,
                color,
                parent: prospective_parent,
                left: Pointer::Null,
                right: Pointer::Null
            }
        );

        // Rebalance, recolor as needed.
        if (color is Color::Red) self.fix_after_insert()
    }

    fun fix_after_insert<V: drop>(self: &Map<V>) {}

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

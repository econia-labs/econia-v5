/// Based on Wikipedia reference implementation of red-black tree.
module red_black_map::red_black_map {

    use std::vector;

    enum Color has copy, drop {
        Red,
        Black
    }

    const NIL: u64 = 0xffffffffffffffff;

    const LEFT: u64 = 0;
    const MINIMUM: u64 = 0;
    const PREDECESSOR: u64 = 0;

    const RIGHT: u64 = 1;
    const MAXIMUM: u64 = 1;
    const SUCCESSOR: u64 = 1;

    /// Map key already exists.
    const E_KEY_ALREADY_EXISTS: u64 = 0;
    /// Map key not found.
    const E_KEY_NOT_FOUND: u64 = 1;
    /// Map is empty.
    const E_EMPTY: u64 = 2;
    /// No predecessor or successor.
    const E_UNABLE_TO_TRAVERSE: u64 = 3;

    struct Node<V> {
        key: u256,
        value: V,
        color: Color,
        parent: u64,
        children: vector<u64>
    }

    struct Map<V> {
        root: u64,
        nodes: vector<Node<V>>
    }

    public fun add<V>(self: &mut Map<V>, key: u256, value: V) {

        // Verify key does not already exist, push new node to back of nodes vector.
        let (node_index, parent_index, child_direction) = self.search(key);
        assert!(node_index == NIL, E_KEY_ALREADY_EXISTS);
        node_index = self.nodes.length();
        self.nodes.push_back(
            Node {
                key,
                value,
                color: Color::Red,
                parent: parent_index,
                children: vector[NIL, NIL]
            }
        );

        // If tree is empty, set root to new node.
        if (parent_index == NIL) {
            self.root = node_index;
            return
        };

        // Set new node as child to parent on specified side.
        self.nodes[parent_index].children[child_direction] = node_index;

        loop {
            let parent_ref_mut = &mut self.nodes[parent_index];

            // Case_I1
            if (parent_ref_mut.color is Color::Black)
                return;

            // From now on parent is red.
            let grandparent_index = parent_ref_mut.parent;

            // Case_I4
            if (grandparent_index == NIL) {
                parent_ref_mut.color = Color::Black;
                return
            };

            // From now on parent is red and grandparent is not NIL.
            let grandparent_ref_mut = &mut self.nodes[grandparent_index];
            let child_direction_of_parent =
                if (parent_index == grandparent_ref_mut.children[LEFT]) LEFT
                else RIGHT;
            let uncle_index = grandparent_ref_mut.children[1
                - child_direction_of_parent];

            // Case_I56
            if (uncle_index == NIL || (self.nodes[uncle_index].color is Color::Black)) {
                // Case_I5
                if (node_index
                    == self.nodes[parent_index].children[1 - child_direction_of_parent]) {
                    parent_index = self.rotate_parent_is_not_root(
                        parent_index, child_direction_of_parent
                    );
                };
                // Case_I6
                self.rotate_parent_may_be_root(
                    grandparent_index, 1 - child_direction_of_parent
                );
                self.nodes[parent_index].color = Color::Black;
                self.nodes[grandparent_index].color = Color::Red;
                return;
            };

            // Case_I2
            self.nodes[parent_index].color = Color::Black;
            self.nodes[uncle_index].color = Color::Black;
            let grandparent_ref_mut = &mut self.nodes[grandparent_index];
            grandparent_ref_mut.color = Color::Red;

            // Iterate 1 black level higher.
            node_index = grandparent_index;
            parent_index = grandparent_ref_mut.parent;

            if (parent_index == NIL) return;
        }; // Case_I3
    }

    public fun borrow<V>(self: &Map<V>, key: u256): &V {
        let (node_index, _, _) = self.search(key);
        assert!(node_index != NIL, E_KEY_NOT_FOUND);
        &self.nodes[node_index].value
    }

    public fun borrow_mut<V>(self: &mut Map<V>, key: u256): &mut V {
        let (node_index, _, _) = self.search(key);
        assert!(node_index != NIL, E_KEY_NOT_FOUND);
        &mut self.nodes[node_index].value
    }

    public fun contains_key<V>(self: &Map<V>, key: u256): bool {
        let (node_index, _, _) = self.search(key);
        node_index != NIL
    }

    public fun keys<V>(self: &Map<V>): vector<u256> {
        vector::map_ref(&self.nodes, |node| node.key)
    }

    public fun length<V>(self: &Map<V>): u64 {
        self.nodes.length()
    }

    public fun maximum_key<V>(self: &Map<V>): u256 {
        assert!(self.root != NIL, E_EMPTY);
        self.subtree_min_or_max_node_ref(self.root, MAXIMUM).key
    }

    public fun minimum_key<V>(self: &Map<V>): u256 {
        assert!(self.root != NIL, E_EMPTY);
        self.subtree_min_or_max_node_ref(self.root, MINIMUM).key
    }

    public fun new<V>(): Map<V> {
        Map { root: NIL, nodes: vector[] }
    }

    public fun predecessor_key<V>(self: &Map<V>, key: u256): u256 {
        let (node_index, _, _) = self.search(key);
        assert!(node_index != NIL, E_KEY_NOT_FOUND);
        self.traverse_ref(node_index, PREDECESSOR).key
    }

    public fun remove<V>(self: &mut Map<V>, key: u256): V {
        let (node_index, parent_index, child_direction) = self.search(key);
        assert!(node_index != NIL, E_KEY_NOT_FOUND);

        // Borrow node and inspect fields.
        let nodes_ref_mut = &mut self.nodes;
        let node_ref_mut = &mut nodes_ref_mut[node_index];
        let left_child_index = node_ref_mut.children[LEFT];
        let right_child_index = node_ref_mut.children[RIGHT];

        // Simple case 1: node has 2 children.
        if (left_child_index != NIL && right_child_index != NIL) {

            // Get node's color and parent index for upcoming position swap.
            let node_color = node_ref_mut.color;
            let node_parent = node_ref_mut.parent;

            // Identify successor (leftmost child of right subtree).
            let successor_index = right_child_index;
            let successor_ref_mut;
            let child_index;
            loop {
                successor_ref_mut = &mut nodes_ref_mut[successor_index];
                child_index = successor_ref_mut.children[LEFT];
                if (child_index == NIL) break;
                successor_index = child_index;
            };

            // Swap positions in the tree. Note that since the successor is leftmost, it can have at
            // most a right child. The deleted node's fields do not need to be updated since it will
            // be removed from the tree.
            let successor_parent_index = successor_ref_mut.parent;
            let successor_right_child_index = successor_ref_mut.children[RIGHT];
            successor_ref_mut.color = node_color;
            successor_ref_mut.parent = node_parent;
            successor_ref_mut.children = vector[left_child_index, right_child_index];
            nodes_ref_mut.swap(node_index, successor_index);

            // Delete relocated node from the tree. Note that after the relocation it has at most a
            // right child that will take its place.
            let successor_parent_ref_mut = &mut nodes_ref_mut[successor_parent_index];
            let successor_child_direction =
                if (successor_index == successor_parent_ref_mut.children[LEFT]) LEFT
                else RIGHT;
            successor_parent_ref_mut.children[successor_child_direction] = successor_right_child_index;
            if (successor_right_child_index != NIL) {
                nodes_ref_mut[successor_right_child_index].parent = successor_parent_index;
            };

            node_index = successor_index; // Flag updated index for deallocation.

            // Simple case 2: node has 1 child.
        } else if (left_child_index != NIL || right_child_index != NIL) {
            let child_index =
                if (left_child_index != NIL) left_child_index
                else right_child_index;

            // Replace node with its child, which is then colored black.
            let child_ref_mut = &mut nodes_ref_mut[child_index];
            child_ref_mut.parent = parent_index;
            child_ref_mut.color = Color::Black;
            nodes_ref_mut.swap(node_index, child_index);

            node_index = child_index; // Flag updated index for deallocation.
        };

        swap_remove_deleted_node(self, node_index)

    }

    public fun successor_key<V>(self: &Map<V>, key: u256): u256 {
        let (node_index, _, _) = self.search(key);
        assert!(node_index != NIL, E_KEY_NOT_FOUND);
        self.traverse_ref(node_index, SUCCESSOR).key
    }

    public fun values_ref<V: copy>(self: &Map<V>): vector<V> {
        vector::map_ref(&self.nodes, |node| node.value)
    }

    inline fun rotate_inner<V>(
        self: &mut Map<V>, parent_index: u64, direction: u64
    ): (u64, u64) {
        let parent_ref = &self.nodes[parent_index];
        // RBnode* G = P->parent;
        let grandparent_index = parent_ref.parent;
        // RBnode* S = P->child[1-dir];
        let subtree_index = parent_ref.children[1 - direction];
        // C = S->child[dir];
        let close_nephew_index = self.nodes[subtree_index].children[direction];
        // P->child[1-dir] = C;
        self.nodes[parent_index].children[1 - direction] = close_nephew_index;
        // if (C != NIL) C->parent = P;
        if (close_nephew_index != NIL) {
            self.nodes[close_nephew_index].parent = parent_index;
        };
        // S->child[  dir] = P;
        self.nodes[subtree_index].children[direction] = parent_index;
        // P->parent = S;
        self.nodes[parent_index].parent = subtree_index;
        // S->parent = G;
        self.nodes[subtree_index].parent = grandparent_index;
        // return S;
        (subtree_index, grandparent_index)
    }

    inline fun rotate_parent_is_not_root<V>(
        self: &mut Map<V>, parent_index: u64, direction: u64
    ): u64 {
        let (subtree_index, grandparent_index) =
            self.rotate_inner(parent_index, direction);
        // G->child[ P == G->right ? RIGHT : LEFT ] = S;
        let grandparent_ref_mut = &mut self.nodes[grandparent_index];
        let child_direction_of_new_subtree =
            if (parent_index == grandparent_ref_mut.children[RIGHT]) RIGHT
            else LEFT;
        grandparent_ref_mut.children[child_direction_of_new_subtree] = subtree_index;
        subtree_index
    }

    inline fun rotate_parent_may_be_root<V>(
        self: &mut Map<V>, parent_index: u64, direction: u64
    ) {
        let (subtree_index, grandparent_index) =
            self.rotate_inner(parent_index, direction);
        // if (G != NULL)
        //   G->child[ P == G->right ? RIGHT : LEFT ] = S;
        // else
        //   T->root = S;
        if (grandparent_index != NIL) {
            let grandparent_ref_mut = &mut self.nodes[grandparent_index];
            let child_direction_of_new_subtree =
                if (parent_index == grandparent_ref_mut.children[RIGHT]) RIGHT
                else LEFT;
            grandparent_ref_mut.children[child_direction_of_new_subtree] = subtree_index;
        } else {
            self.root = subtree_index;
        }
    }

    /// # Returns
    ///
    /// ## If `key` is found
    /// - `u64`: Index of the node containing `key`.
    /// - `u64`: Index of the node that is parent to the node with `key`, `NIL` if `key` is at root.
    /// - `u64`: Direction of the node with `key` as child to its parent, `NIL` if `key` is at root.
    ///
    /// ## If `key` is not found
    /// - `u64`: `NIL`
    /// - `u64`: Index of the node that is parent to the node where `key` should be inserted, `NIL`
    ///   if tree is empty.
    /// - `u64`: Direction of the node where `key` should be inserted as child to its parent, `NIL`
    ///   if tree is empty.
    inline fun search<V>(self: &Map<V>, key: u256): (u64, u64, u64) {
        let current_index = self.root;
        let parent_index = NIL;
        let child_direction = NIL;
        let current_node_ref;
        let current_key;
        while (current_index != NIL) {
            current_node_ref = &self.nodes[current_index];
            current_key = current_node_ref.key;
            if (key == current_key) break;
            parent_index = current_index;
            child_direction = if (key < current_key) LEFT else RIGHT;
            current_index = current_node_ref.children[child_direction];
        };
        (current_index, parent_index, child_direction)
    }

    /// Return reference to node with either minimum or maximum key in subtree rooted at
    /// `node_index`, where `direction` is either `MINIMUM` or `MAXIMUM`, corresponding respectively
    /// to traversing left or right children.
    inline fun subtree_min_or_max_node_ref<V>(
        self: &Map<V>, node_index: u64, direction: u64
    ): &Node<V> {
        let nodes_ref = &self.nodes;
        let node_ref = &nodes_ref[node_index];
        let child_index;
        loop {
            child_index = node_ref.children[direction];
            if (child_index == NIL) break;
            node_ref = &nodes_ref[child_index];
        };
        node_ref
    }

    inline fun swap_remove_deleted_node<V>(
        self: &mut Map<V>, node_index: u64
    ): V {

        // If deleted node is not tail, swap index references.
        let tail_index = self.nodes.length() - 1;
        if (node_index != tail_index) {
            // Get indices of nodes referencing the swapped node from the tail.
            let tail_node_ref = self.nodes.borrow(tail_index);
            let parent_index = tail_node_ref.parent;
            let left_child_index = tail_node_ref.children[LEFT];
            let right_child_index = tail_node_ref.children[RIGHT];

            // Update parent reference to swapped node.
            if (parent_index == NIL) {
                self.root = node_index;
            } else {
                let parent_ref_mut = &mut self.nodes[parent_index];
                let child_direction =
                    if (tail_index == parent_ref_mut.children[LEFT]) LEFT
                    else RIGHT;
                parent_ref_mut.children[child_direction] = node_index;
            };

            // Update children references to swapped node.
            if (left_child_index != NIL) {
                self.nodes[left_child_index].parent = node_index;
            };
            if (right_child_index != NIL) {
                self.nodes[right_child_index].parent = node_index;
            };

            // Swap node with tail.
            self.nodes.swap(node_index, tail_index);
        };

        let Node { value,.. } = self.nodes.pop_back();
        value
    }

    /// Return reference to either predecessor or successor of node with `node_index` key, where
    /// `direction` is either `PREDECESSOR` or `SUCCESSOR`.
    inline fun traverse_ref<V>(
        self: &Map<V>, node_index: u64, direction: u64
    ): &Node<V> {
        let child_index = self.nodes[node_index].children[direction];
        if (child_index != NIL) {
            self.subtree_min_or_max_node_ref(child_index, 1 - direction)
        } else {
            let nodes_ref = &self.nodes;
            let parent_index;
            let parent_ref;
            loop {
                parent_index = nodes_ref[node_index].parent;
                if (parent_index == NIL) {
                    break;
                };
                parent_ref = &nodes_ref[parent_index];
                if (node_index != parent_ref.children[direction]) {
                    break;
                };
                node_index = parent_index;
            };
            assert!(parent_index != NIL, E_UNABLE_TO_TRAVERSE);
            &nodes_ref[parent_index]
        }
    }

    #[test_only]
    struct MockNode<V: drop> has copy, drop {
        key: u256,
        value: V,
        color: Color,
        parent: u64,
        children: vector<u64>
    }

    #[test_only]
    struct MockSearchResult has drop {
        node_index: u64,
        parent_index: u64,
        child_direction: u64
    }

    #[test_only]
    fun assert_node<V: copy + drop>(
        self: &Map<V>, index: u64, expected: MockNode<V>
    ) {
        let node = &self.nodes[index];
        assert!(node.key == expected.key);
        assert!(node.value == expected.value);
        assert!(node.color == expected.color);
        assert!(node.parent == expected.parent);
        assert!(node.children == expected.children);
    }

    #[test_only]
    public fun assert_root_index<V>(self: &Map<V>, expected: u64) {
        assert!(self.root == expected);
    }

    #[test_only]
    fun assert_search_result<V>(
        self: &Map<V>, key: u256, expected: MockSearchResult
    ) {
        let (node_index, parent_index, child_direction) = self.search(key);
        assert!(node_index == expected.node_index);
        assert!(parent_index == expected.parent_index);
        assert!(child_direction == expected.child_direction);
    }

    #[test_only]
    //                  |
    //                  8 (red, i = 2)
    //                 / \
    // (black, i = 0) 5   10 (black, i = 1)
    //                   /  \
    //     (red, i = 4) 9    11 (red, i = 3)
    public fun set_up_tree_1(): Map<u256> {
        let map = new();
        map.add(5, 5);
        map.add(10, 10);
        map.add(8, 8);
        map.add(11, 11);
        map.add(9, 9);
        map.assert_root_index(2);
        map.assert_node(
            0,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Black,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Black,
                parent: 2,
                children: vector[4, 3]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 8,
                value: 8,
                color: Color::Red,
                parent: NIL,
                children: vector[0, 1]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 11,
                value: 11,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 9,
                value: 9,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map
    }

    #[test_only]
    //                    |
    //       (red, i = 1) 30
    //                   /  \
    //  (black, i = 2) 20    50 (black, i = 0)
    //                /  \
    // (red, i = 4) 10    25 (red, i = 3)
    public fun set_up_tree_2(): Map<u256> {
        let map = new();
        map.add(50, 50);
        map.add(30, 30);
        map.add(20, 20);
        map.add(25, 25);
        map.add(10, 10);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 50,
                value: 50,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 30,
                value: 30,
                color: Color::Red,
                parent: NIL,
                children: vector[2, 0]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 20,
                value: 20,
                color: Color::Black,
                parent: 1,
                children: vector[4, 3]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 25,
                value: 25,
                color: Color::Red,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Red,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_ALREADY_EXISTS)]
    fun test_add_already_exists(): Map<u256> {
        let map = new();
        map.add(0, 0);
        map.add(0, 1);
        map
    }

    #[test]
    fun test_add_bulk(): Map<u256> {
        let map = new();

        vector::for_each(
            vector[
                vector[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
                vector[19, 18, 17, 16, 15, 14, 13, 12, 11, 10],
                vector[69, 68, 67, 66, 65, 64, 63, 62, 61, 60],
                vector[20, 21, 22, 23, 24, 25, 26, 27, 28, 29],
                vector[50, 51, 52, 53, 54, 55, 56, 57, 58, 59],
                vector[49, 48, 47, 46, 45, 44, 43, 42, 41, 40],
                vector[30, 31, 32, 33, 34, 35, 36, 37, 38, 39]
            ],
            |key_group| {
                vector::for_each(key_group, |key| {
                    map.add(key, key);
                });
            }
        );

        for (i in 0..70) {
            assert!(map.contains_key(i), (i as u64));
        };

        map
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_borrow_mut_not_found(): Map<u256> {
        let map = new();
        map.borrow_mut(0);
        map
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_borrow_not_found(): Map<u256> {
        let map = new();
        map.borrow(0);
        map
    }

    #[test]
    #[expected_failure(abort_code = E_EMPTY)]
    fun test_maximum_key_empty(): Map<u256> {
        let map = new();
        map.maximum_key();
        map
    }

    #[test]
    #[expected_failure(abort_code = E_EMPTY)]
    fun test_minimum_key_empty(): Map<u256> {
        let map = new();
        map.minimum_key();
        map
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_remove_key_not_found(): Map<u256> {
        let map = set_up_tree_1();
        map.remove(0);
        map
    }

    #[test]
    fun test_sequence_1(): Map<u256> {
        let map = new();
        assert!(map.length() == 0);
        assert!(map.keys() == vector[]);
        assert!(map.values_ref() == vector[]);
        map.assert_root_index(NIL);
        map.assert_search_result(
            0,
            MockSearchResult { node_index: NIL, parent_index: NIL, child_direction: NIL }
        );
        assert!(!map.contains_key(5));

        // Initialize root: insert 5.
        //
        // |
        // 5 (red, i = 0)
        map.add(5, 5);
        assert!(map.keys() == vector[5]);
        assert!(map.length() == 1);
        map.assert_root_index(0);
        assert!(map.contains_key(5));
        map.assert_search_result(
            5, MockSearchResult { node_index: 0, parent_index: NIL, child_direction: NIL }
        );
        map.assert_node(
            0,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Red,
                parent: NIL,
                children: vector[NIL, NIL]
            }
        );
        assert!(minimum_key(&map) == 5);
        assert!(maximum_key(&map) == 5);

        // Case_I4: insert 10.
        //
        // |
        // 5 (black, i = 0)
        //  \
        //   10 (red, i = 1)
        map.add(10, 10);
        assert!(map.keys() == vector[5, 10]);
        map.assert_root_index(0);
        assert!(map.length() == 2);
        assert!(map.contains_key(10));
        map.assert_search_result(
            10, MockSearchResult { node_index: 1, parent_index: 0, child_direction: RIGHT }
        );
        map.assert_search_result(
            11,
            MockSearchResult { node_index: NIL, parent_index: 1, child_direction: RIGHT }
        );
        map.assert_search_result(
            9, MockSearchResult { node_index: NIL, parent_index: 1, child_direction: LEFT }
        );
        map.assert_node(
            0,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Black,
                parent: NIL,
                children: vector[NIL, 1]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Red,
                parent: 0,
                children: vector[NIL, NIL]
            }
        );
        assert!(minimum_key(&map) == 5);
        assert!(maximum_key(&map) == 10);

        // Case_I56 (Case_I5 fall through to Case_I6): insert 8.
        //
        // |                  |                                  |
        // 5 (black, i = 0)   5 (black, i = 0)                   8 (black, i = 2)
        //  \                  \                                / \
        //   10 (red, i = 1) -> 8 (red, i = 2) -> (red, i = 0) 5   10 (red, i = 1)
        //  /                    \
        // 8 (red, i = 2)         10 (red, i = 1)
        map.add(8, 8);
        map.assert_root_index(2);
        assert!(map.contains_key(5));
        assert!(map.contains_key(8));
        assert!(map.contains_key(10));
        map.assert_search_result(
            8, MockSearchResult { node_index: 2, parent_index: NIL, child_direction: NIL }
        );
        map.assert_search_result(
            5, MockSearchResult { node_index: 0, parent_index: 2, child_direction: LEFT }
        );
        map.assert_search_result(
            10, MockSearchResult { node_index: 1, parent_index: 2, child_direction: RIGHT }
        );
        map.assert_search_result(
            11,
            MockSearchResult { node_index: NIL, parent_index: 1, child_direction: RIGHT }
        );
        map.assert_search_result(
            9, MockSearchResult { node_index: NIL, parent_index: 1, child_direction: LEFT }
        );
        map.assert_search_result(
            4, MockSearchResult { node_index: NIL, parent_index: 0, child_direction: LEFT }
        );
        map.assert_search_result(
            6,
            MockSearchResult { node_index: NIL, parent_index: 0, child_direction: RIGHT }
        );
        map.assert_node(
            0,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Red,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Red,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 8,
                value: 8,
                color: Color::Black,
                parent: NIL,
                children: vector[0, 1]
            }
        );
        assert!(minimum_key(&map) == 5);
        assert!(maximum_key(&map) == 10);

        // Case_I2 fall through to Case_I3: insert 11.
        //
        //                |                                     |
        //                8 (black, i = 2)                      8 (red, i = 2)
        //               / \                                   / \
        // (red, i = 0) 5   10 (red, i = 1) -> (black, i = 0) 5   10 (black, i = 1)
        //                    \                                     \
        //                     11 (red, i = 3)                       11 (red, i = 3)
        map.add(11, 11);
        map.assert_root_index(2);
        map.assert_node(
            0,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Black,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Black,
                parent: 2,
                children: vector[NIL, 3]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 8,
                value: 8,
                color: Color::Red,
                parent: NIL,
                children: vector[0, 1]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 11,
                value: 11,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        assert!(minimum_key(&map) == 5);
        assert!(maximum_key(&map) == 11);

        // Case_I1: insert 9.
        //
        //                  |
        //                  8 (red, i = 2)
        //                 / \
        // (black, i = 0) 5   10 (black, i = 1)
        //                   /  \
        //     (red, i = 4) 9    11 (red, i = 3)
        map.add(9, 9);
        map.assert_root_index(2);
        map.assert_node(
            0,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Black,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Black,
                parent: 2,
                children: vector[4, 3]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 8,
                value: 8,
                color: Color::Red,
                parent: NIL,
                children: vector[0, 1]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 11,
                value: 11,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 9,
                value: 9,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );

        // Verify borrows.
        assert!(*map.borrow(9) == 9);
        *map.borrow_mut(9) = 1000;
        assert!(*map.borrow(9) == 1000);
        *map.borrow_mut(9) = 9;
        assert!(*map.borrow(9) == 9);

        // Verify value extraction.
        *map.borrow_mut(5) = 105;
        *map.borrow_mut(10) = 110;
        *map.borrow_mut(8) = 108;
        *map.borrow_mut(11) = 111;
        *map.borrow_mut(9) = 109;
        assert!(
            map.values_ref() == vector[105, 110, 108, 111, 109]
        );
        *map.borrow_mut(5) = 5;
        *map.borrow_mut(10) = 10;
        *map.borrow_mut(8) = 8;
        *map.borrow_mut(11) = 11;
        *map.borrow_mut(9) = 9;

        // Verify traversal.
        assert!(successor_key(&map, 5) == 8);
        assert!(successor_key(&map, 8) == 9);
        assert!(successor_key(&map, 9) == 10);
        assert!(successor_key(&map, 10) == 11);
        assert!(predecessor_key(&map, 11) == 10);
        assert!(predecessor_key(&map, 10) == 9);
        assert!(predecessor_key(&map, 9) == 8);
        assert!(predecessor_key(&map, 8) == 5);

        map
    }

    #[test]
    fun test_sequence_2(): Map<u256> {
        let map = new();

        // Initialize root: insert 50.
        //
        // |
        // 50 (red, i = 0)
        map.add(50, 50);
        map.assert_root_index(0);
        map.assert_node(
            0,
            MockNode {
                key: 50,
                value: 50,
                color: Color::Red,
                parent: NIL,
                children: vector[NIL, NIL]
            }
        );

        // Case_I1: insert 30.
        //
        //                 |
        //                 50 (black, i = 0)
        //                /
        // (red, i = 1) 30
        map.add(30, 30);
        map.assert_root_index(0);
        map.assert_node(
            0,
            MockNode {
                key: 50,
                value: 50,
                color: Color::Black,
                parent: NIL,
                children: vector[1, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 30,
                value: 30,
                color: Color::Red,
                parent: 0,
                children: vector[NIL, NIL]
            }
        );

        // Case_I6: insert 20.
        //
        //                 |                  |
        //  (black, i = 0) 50  (black, i = 1) 30
        //                /                  /  \
        // (red, i = 1) 30 -> (red, i = 2) 20    50 (red, i = 0)
        //             /
        //           20 (red, i = 2)
        map.add(20, 20);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 50,
                value: 50,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 30,
                value: 30,
                color: Color::Black,
                parent: NIL,
                children: vector[2, 0]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 20,
                value: 20,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );

        // Case_I2 fall through to Case_I3: insert 25.
        //
        //                 |                                       |
        //  (black, i = 1) 30                         (red, i = 1) 30
        //                /  \                                    /  \
        // (red, i = 2) 20    50 (red, i = 0) -> (black, i = 2) 20    50 (black, i = 0)
        //                \                                       \
        //                 25 (red, i = 3)                         25 (red, i = 3)
        map.add(25, 25);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 50,
                value: 50,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 30,
                value: 30,
                color: Color::Red,
                parent: NIL,
                children: vector[2, 0]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 20,
                value: 20,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, 3]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 25,
                value: 25,
                color: Color::Red,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );

        // Case_I1: insert 10
        //
        //                    |
        //       (red, i = 1) 30
        //                   /  \
        //  (black, i = 2) 20    50 (black, i = 0)
        //                /  \
        // (red, i = 4) 10    25 (red, i = 3)
        map.add(10, 10);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 50,
                value: 50,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 30,
                value: 30,
                color: Color::Red,
                parent: NIL,
                children: vector[2, 0]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 20,
                value: 20,
                color: Color::Black,
                parent: 1,
                children: vector[4, 3]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 25,
                value: 25,
                color: Color::Red,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Red,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );

        // Verify traversal.
        assert!(successor_key(&map, 10) == 20);
        assert!(successor_key(&map, 20) == 25);
        assert!(successor_key(&map, 25) == 30);
        assert!(successor_key(&map, 30) == 50);
        assert!(predecessor_key(&map, 50) == 30);
        assert!(predecessor_key(&map, 30) == 25);
        assert!(predecessor_key(&map, 25) == 20);
        assert!(predecessor_key(&map, 20) == 10);

        map
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_traverse_predecessor_key_not_found(): Map<u256> {
        let map = set_up_tree_2();
        map.predecessor_key(12);
        map
    }

    #[test]
    #[expected_failure(abort_code = E_UNABLE_TO_TRAVERSE)]
    fun test_traverse_predecessor_unable_to_traverse(): Map<u256> {
        let map = set_up_tree_2();
        map.predecessor_key(10);
        map
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_traverse_successor_key_not_found(): Map<u256> {
        let map = set_up_tree_1();
        map.successor_key(12);
        map
    }

    #[test]
    #[expected_failure(abort_code = E_UNABLE_TO_TRAVERSE)]
    fun test_traverse_successor_unable_to_traverse(): Map<u256> {
        let map = set_up_tree_1();
        map.successor_key(11);
        map
    }
}

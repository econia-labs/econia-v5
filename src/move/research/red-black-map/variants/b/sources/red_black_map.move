module red_black_map::red_black_map {

    use std::debug;
    use std::vector;

    enum Color has drop {
        Red,
        Black
    }

    const NIL: u64 = 0xffffffffffffffff;
    const LEFT: u64 = 0;
    const RIGHT: u64 = 1;

    /// Map key already exists.
    const E_KEY_ALREADY_EXISTS: u64 = 0;

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

            // Case_I4
            let grandparent_index = parent_ref_mut.parent;
            if (grandparent_index == NIL) {
                parent_ref_mut.color = Color::Black;
                return
            };

            // From now on parent is red and grandparent is not NIL.
            let grandparent_ref_mut = &mut self.nodes[grandparent_index];
            let direction =
                if (parent_index == grandparent_ref_mut.children[RIGHT]) RIGHT
                else LEFT;
            let uncle_index = grandparent_ref_mut.children[1 - direction];

            // Case_I56
            if (uncle_index == NIL || (self.nodes[uncle_index].color is Color::Black)) {
                // Case_I5
                if (node_index == self.nodes[parent_index].children[1 - direction]) {
                    self.rotate(parent_index, direction);
                    node_index = parent_index;
                    parent_index = self.nodes[grandparent_index].children[direction];
                };
                // Case_I6
                self.rotate(grandparent_index, 1 - direction);
                self.nodes[parent_index].color = Color::Black;
                self.nodes[grandparent_index].color = Color::Red;
                return
            };

            // Case_I2
            self.nodes[parent_index].color = Color::Black;
            self.nodes[uncle_index].color = Color::Black;
            let grandparent_ref_mut = &mut self.nodes[grandparent_index];
            grandparent_ref_mut.color = Color::Red;
            node_index = grandparent_index;
            parent_index = grandparent_ref_mut.parent;

            if (parent_index == NIL) break;
        };

        return; // Case_I3

    }

    public fun contains_key<V>(self: &Map<V>, key: u256): bool {
        let (node_index, _, _) = self.search(key);
        node_index != NIL
    }

    public fun new<V>(): Map<V> {
        Map {
            root: NIL,
            nodes: vector<Node<V>>[]
        }
    }

    /// Get child direction (side of node as child to parent) of non-root node at `node_index`.
    inline fun child_direction<V>(self: &mut Map<V>, node_index: u64): u64 {
        let parent_index = self.nodes[node_index].parent;
        if (self.nodes[parent_index].children[LEFT] == node_index) LEFT
        else RIGHT
    }

    inline fun rotate<V>(
        self: &mut Map<V>, parent_index: u64, direction: u64
    ): u64 {
        let parent_ref = &self.nodes[parent_index];
        // RBnode* G = P->parent;
        let grandparent_index = parent_ref.parent;
        // RBnode* S = P->child[1-dir];
        let subtree_index = parent_ref.children[1 - direction];
        // C = S->child[dir];
        let child_index = self.nodes[subtree_index].children[direction];
        // P->child[1-dir] = C;
        self.nodes[parent_index].children[1 - direction] = child_index;
        // if (C != NIL) C->parent = P;
        if (child_index != NIL) {
            self.nodes[child_index].parent = parent_index;
        };
        // S->child[  dir] = P;
        self.nodes[subtree_index].children[direction] = parent_index;
        // P->parent = S;
        self.nodes[parent_index].parent = subtree_index;
        // S->parent = G;
        self.nodes[subtree_index].parent = grandparent_index;
        // if (G != NULL)
        //   G->child[ P == G->right ? RIGHT : LEFT ] = S;
        // else
        //   T->root = S;
        if (grandparent_index != NIL) {
            let grandparent_ref_mut = &mut self.nodes[grandparent_index];
            let direction =
                if (parent_index == grandparent_ref_mut.children[RIGHT]) RIGHT
                else LEFT;
            grandparent_ref_mut.children[direction] = subtree_index;
        } else {
            self.root = subtree_index;
        };
        // return S;
        subtree_index
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
        let parent_index = NIL;
        let child_direction = NIL;
        let current_index = self.root;
        let current_ref;
        let current_key;
        while (current_index != NIL) {
            current_ref = &self.nodes[current_index];
            current_key = current_ref.key;
            if (key == current_key) break;
            parent_index = current_index;
            child_direction = if (key < current_key) LEFT else RIGHT;
            current_index = current_ref.children[child_direction];
        };
        (current_index, parent_index, child_direction)
    }

    #[test]
    fun test_assorted(): Map<u256> {
        let map = new();

        // Search, insert <0, 0>.
        map.add(0, 0);
        let (node_index, parent_index, child_direction) = map.search(0);
        assert!(node_index == 0);
        assert!(parent_index == NIL);
        assert!(child_direction == NIL);

        // Search, insert <1, 1>.
        let (node_index, parent_index, child_direction) = map.search(1);
        assert!(node_index == NIL);
        assert!(parent_index == 0);
        assert!(child_direction == RIGHT);
        map.add(1, 1);

        // Insert various keys.
        for (i in 2..10) {
            map.add(i, i);
            assert!(map.contains_key(i));
        };

        // Assert even more keys to exercise tree balancing.
        let keys = vector[
            vector[20, 19, 18, 17, 16, 15, 14, 13, 12, 11],
            vector[70, 69, 68, 67, 66, 65, 64, 63, 62, 61],
            vector[21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
            vector[51, 52, 53, 54, 55, 56, 57, 58, 59, 60],
            vector[50, 49, 48, 47, 46, 45, 44, 43, 42, 41],
            vector[31, 32, 33, 34, 35, 36, 37, 38, 39, 40]
        ];
        vector::for_each(
            keys,
            |key_group| {
                vector::for_each(
                    key_group,
                    |key| {
                        map.add(key, key);
                        debug::print(&key);
                    }
                );
            }
        );
        for (i in 0..71) {
            debug::print(&i);
            assert!(map.contains_key(i));
        };

        map
    }
}

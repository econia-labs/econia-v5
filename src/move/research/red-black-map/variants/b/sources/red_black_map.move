module red_black_map::red_black_map {
    enum Color {
        Red,
        Black
    }

    const NIL: u64 = 0xffffffffffffffff;
    const LEFT: u64 = 0;
    const RIGHT: u64 = 1;

    struct Node<V> {
        key: u256,
        value: V,
        color: u64,
        parent: u64,
        children: vector<u64>
    }

    struct Map<V> {
        root: u64,
        nodes: vector<Node<V>>
    }

    public fun new<V>(): Map<V> {
        Map {
            root: NIL,
            nodes: vector<Node<V>>[]
        }
    }

    /// Get child direction (side of node as child to parent) of non-root node at `node_index`.
    inline fun child_direction<V>(self: &Map<V>, node_index: u64): u64 {
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
            grandparent_ref_mut.children[
                if (parent_index == grandparent_ref_mut.children[RIGHT]) RIGHT else LEFT
            ] = subtree_index;
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
        while (current_index != NIL) {
            let current_ref = &self.nodes[current_index];
            let current_key = current_ref.key;
            if (key == current_key) break;
            parent_index = current_index;
            let child_direction = if (key < current_key) LEFT else RIGHT;
            current_index = current_ref.children[child_direction];
        };
        (current_index, parent_index, child_direction)
    }
}

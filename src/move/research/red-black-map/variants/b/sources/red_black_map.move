/// Based on Wikipedia reference implementation of red-black tree.
///
/// # Tree notation
///
/// In test diagrams, nodes are represented as `<KEY><b|r><INDEX>`, for example `10r1` denotes a red
/// node with key 10 at index 1. The symbols `|`, `/`, and backslash (escaped as `\\` in markdown
/// monospace for this doc comment) are used to represent tree edges, with `/` and `\\` placed at
/// the character position directly adjacent to relevant nodes, and `|` placed above the middle
/// character of a node, or the left inner character when it has an even number of characters. The
/// symbol `->` indicates transitions, with exactly one character of space reserved between the
/// closest characters on each side of the transition. For example a left rotation on parent node
/// `8r2` would be represented as:
///
/// >      |            ->      |
/// >     8r2           ->     10b1
/// >        \          ->    /    \
/// >         10b1      -> 8r2      11r3
/// >        /    \     ->    \
/// >     9r4      11r3 ->     9r4
///
/// Note too the use of `_` to extend tree edges when extra space is required:
///
/// >            |            ->        |
/// >           3r3           ->       3b3
/// >        __/   \__        ->    __/   \__
/// >     1b1         5b5     -> 1r1         5b5
/// >        \       /   \    ->    \       /   \
/// >         2b2 4r4     6r6 ->     2b2 4r4     6r6
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

    /// Tree root index is `NIL` but nodes vector is not empty.
    const E_PROPERTY_NIL_ROOT_HAS_NODES: u64 = 4;
    /// Node's parent field does not match expected value.
    const E_PROPERTY_PARENT_NODE_MISMATCH: u64 = 5;
    /// One or more nodes were not visited during tree traversal.
    const E_PROPERTY_STRAY_NODE: u64 = 6;
    /// Consecutive red nodes found in tree.
    const E_PROPERTY_CONSECUTIVE_RED_NODES: u64 = 7;
    /// Total order of keys is violated.
    const E_PROPERTY_TOTAL_ORDER_VIOLATION: u64 = 8;
    /// Invalid direction.
    const E_PROPERTY_DIRECTION_INVALID: u64 = 9;
    /// Black height of subtrees is not equal.
    const E_PROPERTY_BLACK_HEIGHT_VIOLATION: u64 = 10;

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

            if (parent_ref_mut.color is Color::Black) // Case_I1.
                return;

            // From now on parent is red.
            let grandparent_index = parent_ref_mut.parent;

            if (grandparent_index == NIL) { // Case_I4.
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

            // Case_I56.
            if (uncle_index == NIL || (self.nodes[uncle_index].color is Color::Black)) {
                // Case_I5.
                if (node_index
                    == self.nodes[parent_index].children[1 - child_direction_of_parent]) {
                    parent_index = self.rotate_parent_is_not_root(
                        parent_index, child_direction_of_parent
                    );
                };
                // Case_I6.
                self.rotate_parent_may_be_root(
                    grandparent_index, 1 - child_direction_of_parent
                );
                self.nodes[parent_index].color = Color::Black;
                self.nodes[grandparent_index].color = Color::Red;
                return;
            };

            // Case_I2.
            self.nodes[parent_index].color = Color::Black;
            self.nodes[uncle_index].color = Color::Black;
            let grandparent_ref_mut = &mut self.nodes[grandparent_index];
            grandparent_ref_mut.color = Color::Red;

            // Iterate 1 black level higher.
            node_index = grandparent_index;
            parent_index = grandparent_ref_mut.parent;

            if (parent_index == NIL) return;
        }; // Case_I3.
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

    public fun destroy<V: drop>(self: Map<V>) {
        let Map { nodes,.. } = self;
        nodes.destroy(|node| {
            let Node { .. } = node;
        });
    }

    public fun destroy_empty<V>(self: Map<V>) {
        let Map { nodes,.. } = self;
        nodes.destroy_empty();
    }

    public fun is_empty<V>(self: &Map<V>): bool {
        self.root == NIL
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

        // Borrow node, inspect fields.
        let nodes_ref_mut = &mut self.nodes;
        let node_ref_mut = &mut nodes_ref_mut[node_index];
        let left_child_index = node_ref_mut.children[LEFT];
        let right_child_index = node_ref_mut.children[RIGHT];

        // Simple case 1: node has 2 children, will fall through to another case after swap.
        if (left_child_index != NIL && right_child_index != NIL) {

            let node_color = node_ref_mut.color; // Store node's color for tree position swap.

            // Identify successor, the leftmost child of node's right subtree.
            let successor_index = right_child_index;
            let successor_ref_mut;
            let next_left_child_index;
            loop {
                successor_ref_mut = &mut nodes_ref_mut[successor_index];
                next_left_child_index = successor_ref_mut.children[LEFT];
                if (next_left_child_index == NIL) break;
                successor_index = next_left_child_index;
            };

            // Store tree position fields for successor, then overwrite them to those of node. Note
            // that successor position has no left child since it is leftmost.
            let successor_parent_index = successor_ref_mut.parent;
            let successor_right_child_index = successor_ref_mut.children[RIGHT];
            let successor_color = successor_ref_mut.color;
            successor_ref_mut.parent = parent_index;
            successor_ref_mut.children = vector[left_child_index, right_child_index];
            successor_ref_mut.color = node_color;

            // Update tree position fields for node to those of successor, swap vector indices.
            node_ref_mut = &mut nodes_ref_mut[node_index];
            node_ref_mut.parent = successor_parent_index;
            node_ref_mut.children = vector[NIL, successor_right_child_index];
            node_ref_mut.color = successor_color;
            nodes_ref_mut.swap(node_index, successor_index);

            // Reassign local variables for fallthrough to delete relocated node at successor tree
            // position. Note that child direction of successor position is originally right only
            // when the successor loop does not iterate past the right child of the original node,
            // e.g. when the successor is the only node in the right subtree of the original node.
            child_direction = if (right_child_index == successor_index) RIGHT
            else LEFT;
            node_index = successor_index;
            parent_index = successor_parent_index;
            left_child_index = NIL; // Successor position has no left child.
            right_child_index = successor_right_child_index;
            node_ref_mut = &mut nodes_ref_mut[node_index];
        };
        // Simple case 2: node has 1 child.
        if (left_child_index != NIL || right_child_index != NIL) {
            let child_index =
                if (left_child_index != NIL) left_child_index
                else right_child_index;

            // Replace node with its child, which is then colored black.
            let child_ref_mut = &mut nodes_ref_mut[child_index];
            child_ref_mut.parent = parent_index;
            child_ref_mut.color = Color::Black;
            nodes_ref_mut.swap(node_index, child_index);

            node_index = child_index; // Flag updated index for deallocation.
            // From now on node has no children.
        } else if (parent_index == NIL) { // Simple case 3: node has no children and is root.
            self.root = NIL;
            let Node { value,.. } = nodes_ref_mut.pop_back();
            return value
        } else if (node_ref_mut.color is Color::Red) { // Simple case 4: red non-root leaf.
            nodes_ref_mut[parent_index].children[child_direction] = NIL;
        } else { // Complex case: black non-root leaf.

            // Replace node at its parent by NIL.
            let parent_ref_mut = &mut nodes_ref_mut[parent_index];
            parent_ref_mut.children[child_direction] = NIL;

            // Declare loop variables.
            let sibling_index;
            let sibling_ref_mut;
            let distant_nephew_index;
            let close_nephew_index;

            loop {
                sibling_index = parent_ref_mut.children[1 - child_direction];
                sibling_ref_mut = &mut nodes_ref_mut[sibling_index];
                distant_nephew_index = sibling_ref_mut.children[1 - child_direction];
                close_nephew_index = sibling_ref_mut.children[child_direction];

                // Case_D3: node has red sibling, will fall through to another case after rotation,
                // recolor, and reassignment.
                if (sibling_ref_mut.color is Color::Red) {
                    self.rotate_parent_may_be_root(parent_index, child_direction);
                    nodes_ref_mut = &mut self.nodes;
                    nodes_ref_mut[parent_index].color = Color::Red;
                    nodes_ref_mut[sibling_index].color = Color::Black;
                    sibling_index = close_nephew_index;
                    sibling_ref_mut = &mut nodes_ref_mut[sibling_index];
                    close_nephew_index = sibling_ref_mut.children[child_direction];
                    distant_nephew_index = sibling_ref_mut.children[1 - child_direction];
                };
                // Case_D6.
                if (distant_nephew_index != NIL
                    && (nodes_ref_mut[distant_nephew_index].color is Color::Red)) {
                    self.remove_case_d6(
                        parent_index, child_direction, sibling_index, distant_nephew_index
                    );
                    break;
                };
                // Case_D5.
                if (close_nephew_index != NIL
                    && (nodes_ref_mut[close_nephew_index].color is Color::Red)) {
                    self.rotate_parent_is_not_root(sibling_index, 1 - child_direction);
                    nodes_ref_mut = &mut self.nodes;
                    nodes_ref_mut[sibling_index].color = Color::Red;
                    nodes_ref_mut[close_nephew_index].color = Color::Black;
                    distant_nephew_index = sibling_index;
                    sibling_index = close_nephew_index;
                    self.remove_case_d6(
                        parent_index, child_direction, sibling_index, distant_nephew_index
                    );
                    break;
                };
                // Case_D4.
                if (nodes_ref_mut[parent_index].color is Color::Red) {
                    nodes_ref_mut[sibling_index].color = Color::Red;
                    nodes_ref_mut[parent_index].color = Color::Black;
                    break;
                };
                // Case_D2.
                nodes_ref_mut[sibling_index].color = Color::Red;
                let new_node_index = parent_index;
                parent_index = nodes_ref_mut[new_node_index].parent;
                if (parent_index == NIL) break;
                parent_ref_mut = &mut nodes_ref_mut[parent_index];
                child_direction = if (new_node_index == parent_ref_mut.children[LEFT])
                    LEFT


                else RIGHT;
            }; // Case_D1.
        };

        swap_remove_deleted_node(self, node_index) // Deallocate node.

    }

    public fun successor_key<V>(self: &Map<V>, key: u256): u256 {
        let (node_index, _, _) = self.search(key);
        assert!(node_index != NIL, E_KEY_NOT_FOUND);
        self.traverse_ref(node_index, SUCCESSOR).key
    }

    public fun values_ref<V: copy>(self: &Map<V>): vector<V> {
        vector::map_ref(&self.nodes, |node| node.value)
    }

    /// Verify red-black tree properties. `#[test_only]` omitted to enable coverage testing.
    fun verify<V>(self: &Map<V>) {

        // Verify empty tree.
        let root_index = self.root;
        if (root_index == NIL) {
            assert!(self.nodes.is_empty(), E_PROPERTY_NIL_ROOT_HAS_NODES);
        };

        // Recursively verify subtrees.
        let (n_nodes, _) = self.verify_subtree(
            NIL, Color::Black, 0, LEFT, root_index
        );

        // Verify all nodes have been visited.
        assert!(n_nodes == self.length(), E_PROPERTY_STRAY_NODE);
    }

    /// Recursively verify subtree rooted at `node_index`. `#[test_only]` omitted to enable
    /// coverage testing.
    fun verify_subtree<V>(
        self: &Map<V>,
        parent_index: u64,
        parent_color: Color,
        parent_key: u256,
        child_direction: u64,
        node_index: u64
    ): (u64, u64) {
        // If node index is NIL, return 0 nodes in subtree and 0 black height.
        if (node_index == NIL) return (0, 0);

        // Borrow node, verify its parent field.
        let node_ref = &self.nodes[node_index];
        assert!(node_ref.parent == parent_index, E_PROPERTY_PARENT_NODE_MISMATCH);

        // Initialize subtree black height counter based on subtree root node color.
        let black_height = if (node_ref.color is Color::Black) 1 else 0;

        // For non-root node, verify no consecutive red nodes and total order of keys.
        if (parent_index != NIL) {
            if (parent_color is Color::Red) {
                assert!(node_ref.color is Color::Black, E_PROPERTY_CONSECUTIVE_RED_NODES);
            };
            if (child_direction == LEFT) {
                assert!(node_ref.key < parent_key, E_PROPERTY_TOTAL_ORDER_VIOLATION);
            } else if (child_direction == RIGHT) {
                assert!(node_ref.key > parent_key, E_PROPERTY_TOTAL_ORDER_VIOLATION);
            } else {
                abort E_PROPERTY_DIRECTION_INVALID;
            };
        };

        // Get child indices.
        let left_child_index = node_ref.children[LEFT];
        let right_child_index = node_ref.children[RIGHT];

        // Get number of nodes, black heights by recursively verifying two subtrees.
        let (n_nodes_left_subtree, black_height_left_subtree) =
            self.verify_subtree(
                node_index, node_ref.color, node_ref.key, LEFT, left_child_index
            );
        let (n_nodes_right_subtree, black_height_right_subtree) =
            self.verify_subtree(
                node_index, node_ref.color, node_ref.key, RIGHT, right_child_index
            );

        // Verify equal black height in left and right subtrees.
        assert!(
            black_height_left_subtree == black_height_right_subtree,
            E_PROPERTY_BLACK_HEIGHT_VIOLATION
        );

        // Return total number of nodes visited and black height of subtree.
        (
            1 + n_nodes_left_subtree + n_nodes_right_subtree,
            black_height + black_height_left_subtree
        )
    }

    inline fun remove_case_d6<V>(
        self: &mut Map<V>,
        parent_index: u64,
        child_direction: u64,
        sibling_index: u64,
        distant_nephew_index: u64
    ) {
        self.rotate_parent_may_be_root(parent_index, child_direction);
        let nodes_ref_mut = &mut self.nodes;
        nodes_ref_mut[sibling_index].color = nodes_ref_mut[parent_index].color;
        nodes_ref_mut[parent_index].color = Color::Black;
        nodes_ref_mut[distant_nephew_index].color = Color::Black;
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

    /*inline*/
    fun rotate_parent_may_be_root<V>(
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
    public fun first_black_non_root_leaf_in_nodes_vector<V>(
        self: &Map<V>
    ): u64 {
        let node_ref;
        for (node_index in 0..self.length()) {
            node_ref = &self.nodes[node_index];
            if ((node_ref.color is Color::Black)
                && node_ref.children == vector[NIL, NIL]
                && node_ref.parent != NIL) {
                return node_index;
            };
        };
        NIL
    }

    #[test_only]
    public fun first_case_d3_d5_node_index<V>(self: &Map<V>): u64 {
        let node_ref;
        let parent_ref;
        let parent_index;
        let sibling_ref;
        let sibling_index;
        let child_direction;
        let nodes_ref = &self.nodes;
        let close_nephew_index;
        let new_distant_nephew_index;
        let new_close_nephew_index;
        for (node_index in 0..self.length()) {
            node_ref = &nodes_ref[node_index];
            if (node_ref.color is Color::Red) continue; // From now on is black.
            parent_index = node_ref.parent;
            if (parent_index == NIL) continue; // From now on is black non-root leaf.
            parent_ref = &nodes_ref[parent_index];
            child_direction = if (node_index == parent_ref.children[LEFT]) LEFT
            else RIGHT;
            sibling_index = parent_ref.children[1 - child_direction];
            sibling_ref = &nodes_ref[sibling_index];
            if (sibling_ref.color is Color::Black) continue; // From now on is case D3.
            close_nephew_index = sibling_ref.children[child_direction];

            // Simluate check that triggers Case_D6.
            new_distant_nephew_index = nodes_ref[close_nephew_index].children[1
                - child_direction];
            if (new_distant_nephew_index != NIL
                && (nodes_ref[new_distant_nephew_index].color is Color::Red))
                continue;

            // Identify Case_D5 fall through check.
            new_close_nephew_index = nodes_ref[close_nephew_index].children[child_direction];
            if (new_close_nephew_index != NIL
                && (nodes_ref[new_close_nephew_index].color is Color::Red)) {
                return node_index;
            };

        };
        NIL
    }

    #[test_only]
    //      |
    //     8r2
    //    /   \
    // 5b0     10b1
    //        /    \
    //     9r4      11r3
    public fun set_up_tree_1(): Map<u256> {
        let map = new();
        map.add(5, 5);
        map.verify();
        map.add(10, 10);
        map.verify();
        map.add(8, 8);
        map.verify();
        map.add(11, 11);
        map.verify();
        map.add(9, 9);
        map.verify();
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
        map.verify();
        map
    }

    #[test_only]
    //            |
    //           30r1
    //          /    \
    //      20b2      50b0
    //     /    \
    // 10r4      25r3
    public fun set_up_tree_2(): Map<u256> {
        let map = new();
        map.add(50, 50);
        map.verify();
        map.add(30, 30);
        map.verify();
        map.add(20, 20);
        map.verify();
        map.add(25, 25);
        map.verify();
        map.add(10, 10);
        map.verify();
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
        map.verify();
        map
    }

    #[test_only]
    //      |
    //     1b1
    //    /   \
    // 0b0     3r3
    //        /   \
    //     2b2     5b5
    //            /   \
    //         4r4     6r6
    public fun set_up_tree_3(): Map<u256> {
        let map = new();
        for (i in 0..7) {
            map.add(i, i);
            map.verify();
        };
        assert!(map.length() == 7);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 0,
                value: 0,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 1,
                value: 1,
                color: Color::Black,
                parent: NIL,
                children: vector[0, 3]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 2,
                value: 2,
                color: Color::Black,
                parent: 3,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 3,
                value: 3,
                color: Color::Red,
                parent: 1,
                children: vector[2, 5]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 4,
                value: 4,
                color: Color::Red,
                parent: 5,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            5,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Black,
                parent: 3,
                children: vector[4, 6]
            }
        );
        map.assert_node(
            6,
            MockNode {
                key: 6,
                value: 6,
                color: Color::Red,
                parent: 5,
                children: vector[NIL, NIL]
            }
        );
        map.verify();
        map

    }

    #[test_only]
    //       |
    //      15b1
    //     /    \
    // 10b0      20r2
    //          /    \
    //      19b3      21b4
    //     /
    // 17r5
    public fun set_up_tree_4(): Map<u256> {
        let map = new();
        map.add(10, 10);
        map.add(15, 15);
        map.add(20, 20);
        map.add(19, 19);
        map.add(21, 21);
        map.add(17, 17);
        map.verify();
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 15,
                value: 15,
                color: Color::Black,
                parent: NIL,
                children: vector[0, 2]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 20,
                value: 20,
                color: Color::Red,
                parent: 1,
                children: vector[3, 4]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 19,
                value: 19,
                color: Color::Black,
                parent: 2,
                children: vector[5, NIL]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 21,
                value: 21,
                color: Color::Black,
                parent: 2,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            5,
            MockNode {
                key: 17,
                value: 17,
                color: Color::Red,
                parent: 3,
                children: vector[NIL, NIL]
            }
        );
        map
    }

    #[test_only]
    // Set up a large tree.
    public fun set_up_tree_5(): (Map<u256>, vector<vector<u256>>) {
        let map = new();
        let keys = vector[
            vector[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
            vector[19, 18, 17, 16, 15, 14, 13, 12, 11, 10],
            vector[69, 68, 67, 66, 65, 64, 63, 62, 61, 60],
            vector[20, 21, 22, 23, 24, 25, 26, 27, 28, 29],
            vector[50, 51, 52, 53, 54, 55, 56, 57, 58, 59],
            vector[49, 48, 47, 46, 45, 44, 43, 42, 41, 40],
            vector[30, 31, 32, 33, 34, 35, 36, 37, 38, 39]
        ];
        vector::for_each(
            keys,
            |key_group| {
                vector::for_each(
                    key_group,
                    |key| {
                        map.add(key, key);
                        map.verify();
                    }
                );
            }
        );
        (map, keys)
    }

    #[test_only]
    //           |
    //          15b1
    //         /    \
    //     10r0      20b2
    //    /    \
    // 9b4      12b3
    //              \
    //               13r5
    public fun set_up_tree_6(): Map<u256> {
        let map = new();
        map.add(10, 10);
        map.add(15, 15);
        map.add(20, 20);
        map.add(12, 12);
        map.add(9, 9);
        map.add(13, 13);
        map.verify();
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Red,
                parent: 1,
                children: vector[4, 3]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 15,
                value: 15,
                color: Color::Black,
                parent: NIL,
                children: vector[0, 2]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 20,
                value: 20,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 12,
                value: 12,
                color: Color::Black,
                parent: 0,
                children: vector[NIL, 5]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 9,
                value: 9,
                color: Color::Black,
                parent: 0,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            5,
            MockNode {
                key: 13,
                value: 13,
                color: Color::Red,
                parent: 3,
                children: vector[NIL, NIL]
            }
        );
        map
    }

    #[test_only]
    public fun strip_red_leaves<V: drop>(self: &mut Map<V>) {
        let keys_to_remove = vector[];
        self.nodes.for_each_ref(|node| {
            if (&node.color == &Color::Red && node.children == vector[NIL, NIL]) {
                keys_to_remove.push_back(node.key);
            };
        });
        keys_to_remove.for_each(|key| {
            self.remove(key);
        });
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_ALREADY_EXISTS)]
    fun test_add_already_exists() {
        let map = new();
        map.add(0, 0);
        map.verify();
        map.add(0, 1);
        map.verify();
        map.destroy();
    }

    #[test]
    fun test_add_remove_bulk() {

        let (map, keys) = set_up_tree_5();
        let n_keys = 0;
        vector::for_each(
            keys,
            |key_group| {
                n_keys = n_keys + key_group.length();
            }
        );
        for (i in 0..n_keys) {
            assert!(map.contains_key((i as u256)));
        };

        vector::for_each(
            keys,
            |key_group| {
                vector::for_each(
                    key_group,
                    |key| {
                        assert!(map.remove(key) == key);
                        map.verify();
                        assert!(!map.contains_key(key));
                    }
                );
            }
        );
        assert!(map.is_empty());
        assert!(map.length() == 0);

        // Repeat in linear order.
        for (i in 0..n_keys) {
            map.add((i as u256), (i as u256));
            assert!(map.contains_key((i as u256)));
            map.verify();
        };
        for (i in 0..n_keys) {
            assert!(map.remove((i as u256)) == (i as u256));
            map.verify();
            assert!(!map.contains_key((i as u256)));
        };

        // Repeat for reverse linear order of removals.
        for (i in 0..n_keys) {
            map.add((i as u256), (i as u256));
            assert!(map.contains_key((i as u256)));
            map.verify();
        };
        for (i in 0..n_keys) {
            let j = n_keys - i - 1;
            assert!(map.remove((j as u256)) == (j as u256));
            map.verify();
            assert!(!map.contains_key((j as u256)));
        };
        map.destroy_empty();

        // Repeat for key groups removed by first occurence of non-root black leaves.
        let (map, _) = set_up_tree_5();
        loop {
            let node_index = map.first_black_non_root_leaf_in_nodes_vector();
            if (node_index == NIL) break;
            let key = map.nodes[node_index].key;
            assert!(map.remove(key) == key);
            map.verify();
            assert!(!map.contains_key(key));
        };
        map.destroy();

    }

    #[test]
    fun test_add_sequence_1() {
        let map = new();
        map.verify();
        assert!(map.length() == 0);
        assert!(map.keys() == vector[]);
        assert!(map.values_ref() == vector[]);
        map.assert_root_index(NIL);
        map.assert_search_result(
            0,
            MockSearchResult { node_index: NIL, parent_index: NIL, child_direction: NIL }
        );
        assert!(!map.contains_key(5));
        map.verify();

        // Initialize root: insert 5.
        //
        //  |
        // 5r0
        map.add(5, 5);
        map.verify();
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
        // 5r0
        //    \
        //     10r1
        map.add(10, 10);
        map.verify();
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
        // Rotate right on 10.
        //
        //  |       ->  |
        // 5b0      -> 5b0
        //    \     ->    \
        //     10r1 ->     8r2
        //    /     ->        \
        // 8r2      ->         10r1
        //
        // Rotate left on 5, recolor.
        //
        //  |           ->      |
        // 5b0          ->     8b2
        //    \         ->    /   \
        //     8r2      -> 5r0     10r1
        //        \     ->
        //         10r1 ->
        map.add(8, 8);
        map.verify();
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
        //      |            ->      |
        //     8b2           ->     8r2
        //    /   \          ->    /   \
        // 5r0     10r1      -> 5b0     10b1
        //             \     ->             \
        //              11r3 ->              11r3
        map.add(11, 11);
        map.verify();
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
        //      |
        //     8r2
        //    /   \
        // 5b0     10b1
        //        /    \
        //     9r4      11r3
        map.add(9, 9);
        map.verify();
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

        map.destroy();
    }

    #[test]
    fun test_add_sequence_2() {
        let map = new();

        // Initialize root: insert 50.
        //
        //  |
        // 50r0
        map.add(50, 50);
        map.verify();
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
        //       |
        //      50b0
        //     /
        // 30r1
        map.add(30, 30);
        map.verify();
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
        //            |   ->       |
        //           50b0 ->      30b1
        //          /     ->     /    \
        //      30r1      -> 20r2      50r0
        //     /          ->
        // 20r2           ->
        map.add(20, 20);
        map.verify();
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
        //       |        ->       |
        //      30b1      ->      30r1
        //     /    \     ->     /    \
        // 20r2      50r0 -> 20b2      50b0
        //     \          ->     \
        //      25r3      ->      25r3
        map.add(25, 25);
        map.verify();
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
        //          |
        //         30r1
        //        /    \
        //    20b2      50b0
        //     /  \
        // 10r4    25r3
        map.add(10, 10);
        map.verify();
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

        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_borrow_mut_not_found() {
        let map = new<u8>();
        map.borrow_mut(0);
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_borrow_not_found() {
        let map = new<u8>();
        map.borrow(0);
        map.destroy();
    }

    #[test]
    fun test_destroy_empty_destroy_when_empty() {
        let map = new<u8>();
        map.destroy_empty();
        let map = new<u8>();
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_EMPTY)]
    fun test_maximum_key_empty() {
        let map = new<u8>();
        map.maximum_key();
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_EMPTY)]
    fun test_minimum_key_empty() {
        let map = new<u8>();
        map.minimum_key();
        map.destroy();
    }

    #[test]
    fun test_remove_1() {
        let map = set_up_tree_1();

        // Case_D6: remove 5.
        //
        // Replace node (5) at parent (8) with NIL.
        //
        //      |            ->  |
        //     8r2           -> 8r2
        //    /   \          ->    \
        // 5b0     10b1      ->     10b1
        //        /    \     ->    /    \
        //     9r4      11r3 -> 9r4      11r3
        //
        // Left rotate at parent (8).
        //
        //  |            ->      |
        // 8r2           ->     10b1
        //    \          ->    /    \
        //     10b1      -> 8r2      11r3
        //    /    \     ->    \
        // 9r4      11r3 ->     9r4
        //
        // Recolor per original positions.
        // - Sibling (10) to color of parent (8), red.
        // - Parent (8) to black.
        // - Distant nephew (11) to black.
        //
        //      |        ->      |
        //     10b1      ->     10r1
        //    /    \     ->    /    \
        // 8r2      11r3 -> 8b2      11b3
        //    \          ->    \
        //     9r4       ->     9r4
        //
        // Deallocate via swap remove.
        //
        //      |        ->      |
        //     10r1      ->     10r1
        //    /    \     ->    /    \
        // 8b2      11b3 -> 8b2      11b3
        //    \          ->    \
        //     9r4       ->     9r0
        assert!(map.remove(5) == 5);
        map.verify();
        assert!(map.length() == 4);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 9,
                value: 9,
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
                parent: NIL,
                children: vector[2, 3]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 8,
                value: 8,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, 0]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 11,
                value: 11,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );

        // Simple case 2: remove 8.
        //
        // Replace node (8) with child (9) via swap to index 0, recolor child (9) black.
        //
        //      |        ->      |
        //     10r1      ->     10r1
        //    /    \     ->    /    \
        // 8b2      11b3 -> 9b2      11b3
        //    \          ->
        //     9r0       ->
        //
        // Deallocate via swap remove on new index 0.
        //
        //      |        ->      |
        //     10r1      ->     10r1
        //    /    \     ->    /    \
        // 9b2      11b3 -> 9b2      11b0
        assert!(map.remove(8) == 8);
        map.verify();
        assert!(map.length() == 3);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 11,
                value: 11,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 10,
                value: 10,
                color: Color::Red,
                parent: NIL,
                children: vector[2, 0]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 9,
                value: 9,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );

        // Simple case 1 (successor is right child), fall through to Case_D4: remove 10.
        //
        // Swap tree position of node (10) with successor (11).
        //
        //      |        ->      |
        //     10r1      ->     11r1
        //    /    \     ->    /    \
        // 9b2      11b0 -> 9b2      10b0
        //
        // Replace node (10) at parent (11) with NIL.
        //
        //      |        ->      |
        //     11r1      ->     11r1
        //    /    \     ->    /
        // 9b2      10b0 -> 9b2
        //
        // Recolor sibling (9) red, parent (11) black.
        //
        //      |   ->      |
        //     11r1 ->     11b1
        //    /     ->    /
        // 9b2      -> 9r2
        //
        // Deallocate via swap remove.
        //
        //      |   ->      |
        //     11b1 ->     11b1
        //    /     ->    /
        // 9r2      -> 9r0
        assert!(map.remove(10) == 10);
        map.verify();
        assert!(map.length() == 2);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 9,
                value: 9,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 11,
                value: 11,
                color: Color::Black,
                parent: NIL,
                children: vector[0, NIL]
            }
        );

        // Simple case 4: remove 9.
        //
        //      |   ->  |
        //     11b1 -> 11b1
        //    /     ->
        // 9r0      ->
        //
        // Deallocate via swap remove.
        //
        //  |   ->  |
        // 11b1 -> 11b0
        assert!(map.remove(9) == 9);
        map.verify();
        assert!(map.length() == 1);
        map.assert_root_index(0);
        map.assert_node(
            0,
            MockNode {
                key: 11,
                value: 11,
                color: Color::Black,
                parent: NIL,
                children: vector[NIL, NIL]
            }
        );

        // Simple case: 3 remove 11.
        assert!(map.remove(11) == 11);
        map.verify();
        assert!(map.length() == 0);
        assert!(map.is_empty());

        map.destroy();
    }

    #[test]
    fun test_remove_2() {
        let map = set_up_tree_1();

        // Simple case 1 (successor is left child), fall through to simple case 4, remove 8.
        //
        // Swap tree position of node (8) with successor (9).
        //
        //      |            ->      |
        //     8r2           ->     9r2
        //    /   \          ->    /   \
        // 5b0     10b1      -> 5b0     10b1
        //        /    \     ->        /    \
        //     9r4      11r3 ->     8r4      11r3
        //
        // Remove node (8).
        //
        //      |            ->      |
        //     9r2           ->     9r2
        //    /   \          ->    /   \
        // 5b0     10b1      -> 5b0     10b1
        //        /    \     ->             \
        //     8r4      11r3 ->              11r3
        //
        // No swap remove deallocation required, since node was tail of nodes vector.
        assert!(map.remove(8) == 8);
        map.verify();
        assert!(map.length() == 4);
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
                key: 9,
                value: 9,
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

        map.destroy();

    }

    #[test]
    fun test_remove_3() {
        let map = set_up_tree_3();

        // Case_D3 fall through to Case_D4: remove 0.
        //
        // Replace node (0) at parent (1) with NIL.
        //
        //      |              ->  |
        //     1b1             -> 1b1
        //    /   \            ->    \
        // 0b0     3r3         ->     3r3
        //        /   \        ->    /   \
        //     2b2     5b5     -> 2b2     5b5
        //            /   \    ->        /   \
        //         4r4     6r6 ->     4r4     6r6
        //
        // Left rotate on parent (1).
        //
        //  |              ->        |
        // 1b1             ->       3r3
        //    \            ->    __/   \__
        //     3r3         -> 1b1         5b5
        //    /   \        ->    \       /   \
        // 2b2     5b5     ->     2b2 4r4     6r6
        //        /   \    ->
        //     4r4     6r6 ->
        //
        // Recolor per original positions.
        // - Parent (1) to red.
        // - Sibling (3) to black.
        //
        //        |            ->        |
        //       3r3           ->       3b3
        //    __/   \__        ->    __/   \__
        // 1b1         5b5     -> 1r1         5b5
        //    \       /   \    ->    \       /   \
        //     2b2 4r4     6r6 ->     2b2 4r4     6r6
        //
        // Update indices per original position.
        // - Sibling to close nephew (2).
        // - Distant nephew to new sibling's right child (NIL).
        // - Close nephew to new sibling's left child (NIL).
        //
        // Recolor per Case_D4:
        // - Sibling (2) to red.
        // - Parent (1) to black.
        //
        //        |            ->        |
        //       3b3           ->       3b3
        //    __/   \__        ->    __/   \__
        // 1r1         5b5     -> 1b1         5b5
        //    \       /   \    ->    \       /   \
        //     2b2 4r4     6r6 ->     2r2 4r4     6r6
        //
        // Deallocate via swap remove.
        //
        //        |            ->        |
        //       3b3           ->       3b3
        //    __/   \__        ->    __/   \__
        // 1b1         5b5     -> 1b1         5b5
        //    \       /   \    ->    \       /   \
        //     2r2 4r4     6r6 ->     2r2 4r4     6r0
        assert!(map.remove(0) == 0);
        map.verify();
        assert!(map.length() == 6);
        map.assert_root_index(3);
        map.assert_node(
            0,
            MockNode {
                key: 6,
                value: 6,
                color: Color::Red,
                parent: 5,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 1,
                value: 1,
                color: Color::Black,
                parent: 3,
                children: vector[NIL, 2]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 2,
                value: 2,
                color: Color::Red,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 3,
                value: 3,
                color: Color::Black,
                parent: NIL,
                children: vector[1, 5]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 4,
                value: 4,
                color: Color::Red,
                parent: 5,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            5,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Black,
                parent: 3,
                children: vector[4, 0]
            }
        );

        map.destroy();
    }

    #[test]
    fun test_remove_4() {
        let map = set_up_tree_3();

        // Remove 6 to set up Case_D5.
        //
        //      |              ->      |
        //     1b1             ->     1b1
        //    /   \            ->    /   \
        // 0b0     3r3         -> 0b0     3r3
        //        /   \        ->        /   \
        //     2b2     5b5     ->     2b2     5b5
        //            /   \    ->            /
        //         4r4     6r6 ->         4r4
        assert!(map.remove(6) == 6);
        map.verify();
        assert!(map.length() == 6);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 0,
                value: 0,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 1,
                value: 1,
                color: Color::Black,
                parent: NIL,
                children: vector[0, 3]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 2,
                value: 2,
                color: Color::Black,
                parent: 3,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 3,
                value: 3,
                color: Color::Red,
                parent: 1,
                children: vector[2, 5]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 4,
                value: 4,
                color: Color::Red,
                parent: 5,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            5,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Black,
                parent: 3,
                children: vector[4, NIL]
            }
        );

        // Case_D5: remove 2.
        //
        // Replace node (2) at parent (3) with NIL.
        //
        //      |          ->      |
        //     1b1         ->     1b1
        //    /   \        ->    /   \
        // 0b0     3r3     -> 0b0     3r3
        //        /   \    ->            \
        //     2b2     5b5 ->             5b5
        //            /    ->            /
        //         4r4     ->         4r4
        //
        // Rotate right on sibling (5).
        //
        //      |          ->      |
        //     1b1         ->     1b1
        //    /   \        ->    /   \
        // 0b0     3r3     -> 0b0     3r3
        //            \    ->            \
        //             5b5 ->             4r4
        //            /    ->                \
        //         4r4     ->                 5b5
        //
        // Recolor per original positions.
        // - Sibling (5) to red
        // - Close nephew (4) to black.
        //
        //      |              ->      |
        //     1b1             ->     1b1
        //    /   \            ->    /   \
        // 0b0     3r3         -> 0b0     3r3
        //            \        ->            \
        //             4r4     ->             4b4
        //                \    ->                \
        //                 5b5 ->                 5r5
        //
        // Update indices per original positions.
        // - Distant nephew to sibling (5).
        // - Sibling to close nephew (4).
        //
        // Fall through to Case_D6, left rotate on parent (3).
        //
        //      |              ->       |
        //     1b1             ->      1b1
        //    /   \            ->     /   \
        // 0b0     3r3         ->  0b0     4b4
        //            \        ->         /   \
        //             4b4     ->      3r3     5r5
        //                \    ->
        //                 5r5 ->
        //
        // Recolor:
        // - New sibling (4) to unchanged parent (3) color red.
        // - Unchanged parent (3) to black.
        // - New distant nephew (5) to black.
        //
        //      |          ->      |
        //     1b1         ->     1b1
        //    /   \        ->    /   \
        // 0b0     4b4     -> 0b0     4r4
        //        /   \    ->        /   \
        //     3r3     5r5 ->     3b3     5b5
        //
        // Deallocate via swap remove.
        //
        //      |          ->      |
        //     1b1         ->     1b1
        //    /   \        ->    /   \
        // 0b0     4r4     -> 0b0     4r4
        //        /   \    ->        /   \
        //     3b3     5b5 ->     3b3     5b2
        assert!(map.remove(2) == 2);
        map.verify();
        assert!(map.length() == 5);
        map.assert_root_index(1);
        map.assert_node(
            0,
            MockNode {
                key: 0,
                value: 0,
                color: Color::Black,
                parent: 1,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            1,
            MockNode {
                key: 1,
                value: 1,
                color: Color::Black,
                parent: NIL,
                children: vector[0, 4]
            }
        );
        map.assert_node(
            2,
            MockNode {
                key: 5,
                value: 5,
                color: Color::Black,
                parent: 4,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            3,
            MockNode {
                key: 3,
                value: 3,
                color: Color::Black,
                parent: 4,
                children: vector[NIL, NIL]
            }
        );
        map.assert_node(
            4,
            MockNode {
                key: 4,
                value: 4,
                color: Color::Red,
                parent: 1,
                children: vector[3, 2]
            }
        );

        map.destroy();
    }

    #[test]
    fun test_remove_5() {
        let map = set_up_tree_4();
        let node_index = map.first_case_d3_d5_node_index();
        assert!(map.nodes[node_index].key == 10);
        assert!(map.remove(10) == 10);
        map.verify();
        map.destroy();
        map = set_up_tree_6();
        node_index = map.first_case_d3_d5_node_index();
        assert!(map.nodes[node_index].key == 20);
        assert!(map.remove(20) == 20);
        map.verify();
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_remove_key_not_found() {
        let map = set_up_tree_1();
        map.remove(0);
        map.verify();
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_traverse_predecessor_key_not_found() {
        let map = set_up_tree_2();
        map.predecessor_key(12);
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_UNABLE_TO_TRAVERSE)]
    fun test_traverse_predecessor_unable_to_traverse() {
        let map = set_up_tree_2();
        map.predecessor_key(10);
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_KEY_NOT_FOUND)]
    fun test_traverse_successor_key_not_found() {
        let map = set_up_tree_1();
        map.successor_key(12);
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_UNABLE_TO_TRAVERSE)]
    fun test_traverse_successor_unable_to_traverse() {
        let map = set_up_tree_1();
        map.successor_key(11);
        map.destroy()
    }

    #[test]
    #[expected_failure(abort_code = E_PROPERTY_BLACK_HEIGHT_VIOLATION)]
    fun test_verify_black_height_violation() {
        let map = set_up_tree_1();
        map.nodes[3].color = Color::Black;
        map.verify();
        map.destroy()
    }

    #[test]
    #[expected_failure(abort_code = E_PROPERTY_CONSECUTIVE_RED_NODES)]
    fun test_verify_consecutive_red_nodes() {
        let map = set_up_tree_1();
        map.nodes[1].color = Color::Red;
        map.verify();
        map.destroy()
    }

    #[test]
    #[expected_failure(abort_code = E_PROPERTY_DIRECTION_INVALID)]
    fun test_verify_direction_invalid() {
        let map = set_up_tree_1();
        map.verify_subtree(
            2, Color::Red, 8, 3, 0
        );
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_PROPERTY_NIL_ROOT_HAS_NODES)]
    fun test_verify_nil_root_has_nodes() {
        let map = new();
        map.nodes.push_back(
            Node {
                key: 0,
                value: 0,
                color: Color::Black,
                parent: NIL,
                children: vector[NIL, NIL]
            }
        );
        map.verify();
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_PROPERTY_PARENT_NODE_MISMATCH)]
    fun test_verify_parent_node_mismatch() {
        let map = set_up_tree_1();
        map.nodes[0].parent = map.length();
        map.verify();
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_PROPERTY_STRAY_NODE)]
    fun test_verify_stray_node() {
        let map = set_up_tree_1();
        map.nodes.push_back(
            Node {
                key: 0,
                value: 0,
                color: Color::Red,
                parent: NIL,
                children: vector[NIL, NIL]
            }
        );
        map.verify();
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_PROPERTY_TOTAL_ORDER_VIOLATION)]
    fun test_verify_total_order_violation_left() {
        let map = set_up_tree_1();
        map.nodes[0].key = 9;
        map.verify();
        map.destroy();
    }

    #[test]
    #[expected_failure(abort_code = E_PROPERTY_TOTAL_ORDER_VIOLATION)]
    fun test_verify_total_order_violation_right() {
        let map = set_up_tree_1();
        map.nodes[3].key = 4;
        map.verify();
        map.destroy();
    }
}

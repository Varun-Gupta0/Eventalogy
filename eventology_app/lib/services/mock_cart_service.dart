class MockCartService {
  static final MockCartService _instance = MockCartService._internal();
  factory MockCartService() => _instance;
  MockCartService._internal();

  final List<String> _cartItems = [];

  void addItem(String itemName) {
    _cartItems.add(itemName);
  }

  List<String> get items => _cartItems;
}

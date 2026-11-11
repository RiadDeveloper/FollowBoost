/// Shared order-pricing rules (must match the backend):
/// follow costs 2 coins per follower, like costs 1 coin per like,
/// with a minimum of 10 coins per order.
class Pricing {
  static int orderCost(String type, int count) {
    if (type == 'follow') {
      final cost = count * 2;
      return cost < 10 ? 10 : cost;
    }
    return count < 10 ? 10 : count;
  }
}

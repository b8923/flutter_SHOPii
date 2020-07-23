import 'dart:async';
import 'dart:convert';
import 'package:ankiishopii/blocs/checkout_bloc/bloc.dart';
import 'package:ankiishopii/blocs/checkout_bloc/event.dart';
import 'package:ankiishopii/blocs/checkout_bloc/service.dart';
import 'package:ankiishopii/blocs/checkout_bloc/state.dart';
import 'package:ankiishopii/blocs/delivery_address_bloc/bloc.dart';
import 'package:ankiishopii/blocs/delivery_address_bloc/event.dart';
import 'package:ankiishopii/blocs/delivery_address_bloc/state.dart';
import 'package:ankiishopii/global/global_function.dart';
import 'package:ankiishopii/models/account_model.dart';
import 'package:ankiishopii/models/ordering_model.dart';
import 'package:ankiishopii/pages/navigator/navigator_page.dart';
import 'package:ankiishopii/pages/ordering/ordering_detail_page.dart';
import 'package:ankiishopii/pages/product/product_detail_page.dart';
import 'package:ankiishopii/themes/constant.dart';
import 'package:ankiishopii/widgets/app_bar.dart';
import 'package:ankiishopii/widgets/product_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CheckOutPage extends StatefulWidget {
  static const String routeName = 'checkoutPage';
  final OrderingModel cart;

  CheckOutPage(this.cart);

  @override
  _CheckOutPageState createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  CheckoutBloc bloc = CheckoutBloc();
  DeliveryAddressBloc deliveryAddressBloc = DeliveryAddressBloc();
  ScrollController _scrollController = ScrollController();
  StreamController _scrollStreamController = StreamController();
  bool _isDoingCheckoutConfirm = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    bloc.add(GetCheckout(widget.cart));
    deliveryAddressBloc.add(GetDeliveryAddress(widget.cart.deliveryId));
    _scrollController.addListener(() {
      bool isScrollUp = _scrollController.position.userScrollDirection == ScrollDirection.reverse;
      _scrollStreamController.sink.add(isScrollUp);
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _scrollStreamController.close();
    bloc.close();
    deliveryAddressBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: BlocBuilder(
          bloc: bloc,
          builder: (context, state) {
            if (state is CheckoutLoaded) {
              return Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Expanded(
                          child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: <Widget>[
                            buildAppBar(),
                            buildDivider(),
                            buildDelivery(state.checkoutModel),
                            buildDivider(),
                            buildPaymentMethod(),
                            buildDivider(),
                            buildListOrderDetail(state.checkoutModel.orderingDetail),
                          ],
                        ),
                      ))
                    ],
                  ),
                  buildBottomBar(state.checkoutModel)
                ],
              );
            }
            return Center(
              child: Text('error'),
            );
          }),
    );
  }

  Widget buildAppBar() {
    return InPageAppBar(
      title: 'Check Out',
      showCartButton: false,
      leading: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Icon(Icons.arrow_back_ios),
      ),
    );
  }

  Widget buildBottomBar(OrderingModel orderingModel) {
    var total = 0;
    for (var orderDetail in orderingModel.orderingDetail) {
      total += orderDetail.count * orderDetail.product.price;
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: StreamBuilder(
          stream: _scrollStreamController.stream,
          builder: (context, snapshot) {
            return AnimatedContainer(
              duration: Duration(milliseconds: 100),
              height: snapshot.hasData && snapshot.data == true ? 0 : kBottomNavigationBarHeight,
              decoration: BoxDecoration(
                  color: BACKGROUND_COLOR,
                  boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, -3), blurRadius: 3)]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                      child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Total:',
                          style: DEFAULT_TEXT_STYLE.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$total đ',
                          style: DEFAULT_TEXT_STYLE.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 20, color: Colors.redAccent),
                        )
                      ],
                    ),
                  )),
                  orderingModel.deliveryId == -1 || orderingModel.status > 0
                      ? Container()
                      : GestureDetector(
                          onTap: () {
                            if (!_isDoingCheckoutConfirm) confirmCheckout(orderingModel);
                          },
                          child: Container(
                            padding: EdgeInsets.all(10),
                            height: 55,
                            width: 110,
                            color: FOREGROUND_COLOR,
                            child: _isDoingCheckoutConfirm
                                ? Center(child: CircularProgressIndicator())
                                : Icon(
                                    Icons.check,
                                    size: 25,
                                  ),
                          ),
                        )
                ],
              ),
            );
          }),
    );
  }

  Widget buildListOrderDetail(List<OrderingDetailModel> listOrderingDetail) {
    return Container(
      margin: EdgeInsets.only(bottom: kBottomNavigationBarHeight + 10),
      child: Column(
        children: listOrderingDetail.map<Widget>((od) {
          var product = od.product;
          return CustomProductCheckOutItem(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (b) => ProductDetailPage(product)));
            },
            backgroundColor: FOREGROUND_COLOR,
            cartItem: od,
          );
        }).toList(),
      ),
    );
  }

  Widget buildDelivery(OrderingModel orderingModel) {
    return GestureDetector(
      onTap: () {
        showAddressChooserDialog(orderingModel);
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        padding: EdgeInsets.all(10),
        child: BlocBuilder(
            bloc: deliveryAddressBloc,
            builder: (context, state) {
              if (state is DeliveryAddressLoaded) {
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 1, child: Text('Name:')),
                              SizedBox(
                                width: 20,
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  state.deliveryAddress.fullname,
                                  textAlign: TextAlign.right,
                                  style: DEFAULT_TEXT_STYLE.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              )
                            ],
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 1, child: Text('Address:')),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  state.deliveryAddress.address,
                                  textAlign: TextAlign.right,
                                  style: DEFAULT_TEXT_STYLE.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              )
                            ],
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 1, child: Text('Phone:')),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  state.deliveryAddress.phoneNumber,
                                  textAlign: TextAlign.right,
                                  style: DEFAULT_TEXT_STYLE.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                );
              } else {
                return Center(
                  child: Text('Please select Delivery Address'),
                );
              }
            }),
      ),
    );
  }

  Widget buildPaymentMethod() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10),
      padding: EdgeInsets.all(10),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Payment Method:'),
              Text(
                'COD',
                style: DEFAULT_TEXT_STYLE.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget buildDivider() {
    return Container(
      height: 1,
      color: Colors.black26,
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
    );
  }

  showAddressChooserDialog(OrderingModel orderingModel) async {
    var rs =
        await showDialog(context: context, barrierDismissible: false, child: Dialog(child: AddressChooserDialog()));
    if (rs != null && rs is DeliveryAddressModel) {
      await CheckoutService().checkOut(orderingModel, deliveryId: rs.id);
      deliveryAddressBloc.add(GetDeliveryAddress(rs.id));
      bloc.add(GetCheckout(orderingModel));
    }
  }

  Future<OrderingModel> confirmCheckout(OrderingModel orderingModel) async {
    setState(() {
      _isDoingCheckoutConfirm = true;
    });
    var isCheckOutOk = await CheckoutService().checkOut(orderingModel, status: 1);
    if (isCheckOutOk != null) {
      await Future.delayed(Duration(seconds: 5));
      print(jsonEncode(isCheckOutOk));
      refreshCart(context);

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (b) => OrderingDetailPage(orderingModel)));
    } else {
      setState(() {
        _isDoingCheckoutConfirm = false;
      });
    }

    return isCheckOutOk;
  }
}

class AddressChooserDialog extends StatefulWidget {
  @override
  _AddressChooserDialogState createState() => _AddressChooserDialogState();
}

class _AddressChooserDialogState extends State<AddressChooserDialog> {
  DeliveryAddressBloc bloc = DeliveryAddressBloc();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    bloc.add(GetAllDeliveryAddresses());
  }

  @override
  void dispose() {
    // TODO: implement dispose
    bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: Container(
        child: SingleChildScrollView(
          child: BlocBuilder(
              bloc: bloc,
              builder: (context, state) {
                if (state is AllDeliveryAddressesLoaded) {
                  return buildListAddress(state.deliveryAddresses);
                } else if (state is DeliveryAddressLoading) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
                return Center(
                  child: Text('You dont have any addresses!!'),
                );
              }),
        ),
      ),
    );
  }

  Widget buildListAddress(List<DeliveryAddressModel> deliveryAddresses) {
    return Column(children: deliveryAddresses.map<Widget>((address) => addressItem(address)).toList());
  }

  Widget addressItem(DeliveryAddressModel deliveryAddressModel) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context, deliveryAddressModel);
      },
      child: Container(
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FOREGROUND_COLOR,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 1, child: Text('Name:')),
                        SizedBox(
                          width: 20,
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            deliveryAddressModel.fullname,
                            textAlign: TextAlign.right,
                            style: DEFAULT_TEXT_STYLE.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        )
                      ],
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 1, child: Text('Address:')),
                        Expanded(
                          flex: 2,
                          child: Text(
                            deliveryAddressModel.address,
                            textAlign: TextAlign.right,
                            style: DEFAULT_TEXT_STYLE.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        )
                      ],
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 1, child: Text('Phone:')),
                        Expanded(
                          flex: 2,
                          child: Text(
                            deliveryAddressModel.phoneNumber,
                            textAlign: TextAlign.right,
                            style: DEFAULT_TEXT_STYLE.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              )
            ],
          )),
    );
  }
}

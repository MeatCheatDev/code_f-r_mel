import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:snupa/business_logic/state_managment/blocs/manage_food/manage_stock/add_stock_scan/food_scan_bloc.dart';
import 'package:snupa_repository/snupa_repository.dart';

class FoodscanScreen extends StatefulWidget {
  const FoodscanScreen({super.key, required this.pageController});

  final PageController pageController;

  @override
  State<FoodscanScreen> createState() => _FoodscanScreenState();
}
/// Hier geht ein Teil des Dramas schon los. Ich habe es nicht geschafft, dass er mir sauber den Barcode Scanner inital startet. Da kam es immer wieder zu problemen
/// Wenn ich den Delay runter mache, öffnet sich bspw. die Kamera einfach nicht. das kann doch schon nicht normal sein dieses Verhalten. Ist schon komisch mir fällt aber kein
/// besserer ansatz ein... Habe auch bereits mehrere Packages probiert. Das problem kam immer wieder, dass sich die kamera einfach nicht geöffnet hat. So der Workaround mit
/// dem Delayed.
///
///
class _FoodscanScreenState extends State<FoodscanScreen> {
  String scannedBarcode = ""; // Variable zum Speichern des Barcode-Textes
  Product? scannedProduct; // Variable zum Speichern des Produktes
  String errorMessage = ""; // Fehlermeldung, falls Produkt nicht gefunden wird

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 125), () {
      if (mounted) startScan(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Barcode Scanner"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () async {
                ///Falls die kamera abkackt (was gelengeltich mal vorgekommen ist), kann er halt hier wieder neu starten... auch eher ein work around als ein feature :D
                await startScan(context);
              },
              child: Icon(Icons.repeat),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> startScan(BuildContext context) async {
    try {
      var result = await BarcodeScanner.scan(
          options: const ScanOptions(
        strings: {
          'cancel': 'Abbrechen',
          'flash_on': 'Blitz an',
          'flash_off': 'Blitz aus',
        },
      ));
      String barcode = result.rawContent;

      if (barcode.isNotEmpty) {
        setState(() {
          scannedBarcode = barcode;
          errorMessage = "";
        });

        await getProduct(barcode, context);
      }
    } catch (e) {
      debugPrint("Fehler beim Scannen: $e");
    }
  }

  Future<void> getProduct(String barcode, BuildContext context) async {
    final ProductQueryConfiguration configuration = ProductQueryConfiguration(
      barcode,
      fields: [ProductField.ALL],
      version: ProductQueryVersion.v3,
    );

    try {
      final ProductResultV3 result = await OpenFoodAPIClient.getProductV3(configuration);

      if (result.status == ProductResultV3.statusSuccess) {
/// Hier drei große Fragezeichen. Ich habe früh gelernt das man sowas eigentlich nicht macht afaik, den context hin und her schicken, vor allem, wie er auch richtig meckert
        /// nicht über Future/Async Gaps hinweg. Weiß nicht, ob der Pratice von BLOC so vorgsehen ist. Bzw. ganz generell, sollte diese ganze FUnktion getProduct nicht dirgend
        /// raus aus dem UI, in einen dedizireten bloc? das ist doch quatsch hier.... :-(
        FoodInStorage fis = FoodInStorage(foodName: result.product!.productName);
        context.read<FoodScanBloc>().add(ScanProductEvent(fis));
      } else {
        setState(() {
          scannedProduct = null;
          errorMessage = "Produkt nicht gefunden!";
        });
      }
    } catch (e) {
      setState(() {
        scannedProduct = null;
        errorMessage = "Fehler beim Abrufen des Produkts.";
      });
    }
  }
}

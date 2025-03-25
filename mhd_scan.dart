import 'package:flutter/Material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snupa/business_logic/state_managment/blocs/manage_food/manage_stock/add_stock_scan/food_scan_bloc.dart';
import 'package:snupa_repository/snupa_repository.dart';

import '../../../../../business_logic/state_managment/cubits/active_storageId/active_storageid_cubit.dart';
import '../../home_root.dart';
import '../foodscan_screen.dart';
import '../scanscreen.dart';

class ScanRoot extends StatefulWidget {
  const ScanRoot({super.key});

  @override
  State<ScanRoot> createState() => _ScanRootState();
}

class _ScanRootState extends State<ScanRoot> {
  final StorageRepository _abstractStorageRepository = StorageRepository();
  final PageController pageController = PageController();

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
  /// Die Wurzel des ganzen. Hier wie gesagt mein Ansatz, dass es wie auf dem Video so ein halbwegs flüssiger ablauf ist. Wenn du da einen besseren Ansatz kennst, sag es mir gerne
  /// Ich denke aber eigentlich passt das mit der PageView

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (context) => FoodScanBloc(abstractStorageRepository: _abstractStorageRepository),
        child: Scaffold(
          body: BlocListener<FoodScanBloc, FoodScanState>(
            listener: (context, state) {
              if (state is FoodScanProductSuccess) {
                pageController.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeIn);
              } else if (state is FoodScanMHDAdded) {
                pageController.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeIn);
              }
            },
            child: Center(
                child: PageView(
              controller: pageController,
              children: [
                FoodscanScreen(
                  pageController: pageController,
                ),
                MHDScannerPage(
                  pageController: pageController,
                ),
                Stack(
                  children: [
                    CheckFood(
                      pageController: pageController,
                    ),
                    Positioned(
                      bottom: 22,
                      left: 12,
                      right: 12,
                      child: AnimatedProgressButton(
                        pageController: pageController,
                        continueTimer: 27,
                      ),
                    )
                  ],
                ),
                ListScannedItems(),
              ],
            )),
          ),
        ));
  }
}

class CheckFood extends StatelessWidget {
  const CheckFood({super.key, required this.pageController});

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FoodScanBloc, FoodScanState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state is FoodScanMHDAdded) ...[
              Text(state.productWithMHD.foodName!),
              Text(state.productWithMHD.deFactoBBDate.toString()),
            ]
          ],
        );
      },
    );
  }
}

class AnimatedProgressButton extends StatefulWidget {
  const AnimatedProgressButton({super.key, required this.pageController, required this.continueTimer});

  final PageController pageController;
  final int continueTimer;

  @override
  State<AnimatedProgressButton> createState() => _AnimatedProgressButtonState();
}

class _AnimatedProgressButtonState extends State<AnimatedProgressButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool isLoading = false;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.continueTimer), // Animationsdauer
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      });

    // Automatischer Start nach Abschluss der Animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startNavigation();
      }
    });

    _controller.forward(); // Startet die Animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startNavigation() {
    widget.pageController.animateToPage(0, duration: Duration(milliseconds: 30), curve: Curves.easeIn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // Abgerundete Ecken
          color: const Color(0x83272727)),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Color(0xff272727), // Hintergrundfarbe des Containers
                  borderRadius: BorderRadius.circular(30), // Abrundung des Containers
                ),
                child: Row(
                  children: [
                    /*       IconButton(
                      onPressed: () {
                        widget.pageController.previousPage(
                          duration: Duration(milliseconds: 380),
                          curve: Curves.ease,
                        );
                      },
                      icon: Icon(Icons.arrow_back_rounded),
                    ),
                    Container(
                      width: 1, // Dicke der Linie
                      height: 30, // Höhe der Linie
                      color: Color(0xff808080), // Farbe der Linie
                    ),*/
                    if (isPaused) ...{
                      IconButton(
                        onPressed: () {
                          _controller.forward(); // Stoppt die Animation, wenn der Button gedrückt wird
                          setState(() {
                            isPaused = false;
                          });
                        },
                        icon: Icon(Icons.play_arrow),
                      ),
                    } else ...[
                      IconButton(
                        onPressed: () {
                          _controller.stop(); // Stoppt die Animation, wenn der Button gedrückt wird
                          setState(() {
                            isPaused = true;
                          });
                        },
                        icon: Icon(Icons.pause),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 16,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    context.read<FoodScanBloc>().add(AddProductToListEvent());
                    widget.pageController.animateToPage(0, duration: Duration(milliseconds: 30), curve: Curves.easeIn);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      // Das Gradient überlagert den roten Hintergrund
                      gradient: LinearGradient(
                        colors: [
                          Colors.green[400]!, // Startfarbe der Animation
                          Colors.green[200]!, // Startfarbe der Animation
                        ],
                        stops: [_animation.value, _animation.value], // Steuert die "Wand" der Animation
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Nächstes Produkt scannen", //  _animation.value < 1.0 ? "Weiter" : "Gestartet!",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 12,
          ),
          TextButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black, backgroundColor: Colors.grey[700], // Textfarbe
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0), // Abgerundete Ecken
              ),
            ),
            onPressed: () {
              context.read<FoodScanBloc>().add(AddProductToListEvent());

              widget.pageController.animateToPage(3, duration: Duration(milliseconds: 40), curve: Curves.easeIn);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Text(
                    "Alle Produkte erfasst",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ListScannedItems extends StatelessWidget {
  const ListScannedItems({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FoodScanBloc, FoodScanState>(
      builder: (context, state) {
        List<FoodInStorage> scannedItems = [];

        // Falls State die Liste beinhaltet, laden wir sie
        if (state is FoodScanListUpdated) {
          scannedItems = state.items;
        }

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🛒 Deine gescannten Produkte:",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: scannedItems.isEmpty
                        ? const Center(
                            child: Text(
                              "Noch keine Produkte gescannt.",
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: scannedItems.length,
                            itemBuilder: (context, index) {
                              final item = scannedItems[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: Text(item.foodName ?? "Unbekanntes Produkt"),
                                  subtitle: Text(
                                    "MHD: ${item.deFactoBBDate?.toIso8601String().substring(0, 10) ?? 'Kein MHD'}",
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      context.read<FoodScanBloc>().add(RemoveProductFromListEvent(item.fisId));
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            // Haken unten rechts
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: Colors.green,
                onPressed: () {
                  // Hochladen und zurück zum HomeRoot
                  context.read<FoodScanBloc>().add(
                        SubmitProductsEvent(context.read<GetActiveStorageIdCubit>().state['storage_uid']!), // Stock ID setzen
                      );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeRoot()),
                    (route) => false,
                  );
                },
                child: const Icon(Icons.check, size: 32),
              ),
            ),
          ],
        );
      },
    );
  }
}

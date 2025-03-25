
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
//................. MEHR CODE; NICHT RELEVANT
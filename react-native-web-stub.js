// React Native web stub for webpack builds
// This provides empty implementations of React Native modules for web builds

export const NativeModules = {};
export const Platform = { OS: 'web' };
export const Dimensions = { get: () => ({ width: 0, height: 0 }) };
export const PixelRatio = { get: () => 1 };
export const StatusBar = { setHidden: () => {} };
export const AppState = { addEventListener: () => {}, removeEventListener: () => {} };
export const BackHandler = { addEventListener: () => {}, removeEventListener: () => {} };
export const Linking = { openURL: () => Promise.resolve() };
export const Alert = { alert: () => {} };
export const ActionSheetIOS = {};
export const Animated = {};
export const Easing = {};
export const LayoutAnimation = {};
export const PanResponder = {};
export const StyleSheet = { create: (styles) => styles };
export const View = () => null;
export const Text = () => null;
export const Image = () => null;
export const TouchableOpacity = () => null;
export const TouchableHighlight = () => null;
export const TouchableWithoutFeedback = () => null;
export const ScrollView = () => null;
export const FlatList = () => null;
export const SectionList = () => null;
export const Switch = () => null;
export const TextInput = () => null;
export const Slider = () => null;
export const Picker = () => null;
export const Modal = () => null;
export const ActivityIndicator = () => null;
export const RefreshControl = () => null;
export const SafeAreaView = () => null;
export const KeyboardAvoidingView = () => null;
export const VirtualizedList = () => null;
export const WebView = () => null;

// Default export
export default {
    NativeModules,
    Platform,
    Dimensions,
    PixelRatio,
    StatusBar,
    AppState,
    BackHandler,
    Linking,
    Alert,
    ActionSheetIOS,
    Animated,
    Easing,
    LayoutAnimation,
    PanResponder,
    StyleSheet,
    View,
    Text,
    Image,
    TouchableOpacity,
    TouchableHighlight,
    TouchableWithoutFeedback,
    ScrollView,
    FlatList,
    SectionList,
    Switch,
    TextInput,
    Slider,
    Picker,
    Modal,
    ActivityIndicator,
    RefreshControl,
    SafeAreaView,
    KeyboardAvoidingView,
    VirtualizedList,
    WebView
};

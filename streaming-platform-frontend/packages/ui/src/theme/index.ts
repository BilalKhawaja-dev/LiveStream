import { extendTheme, type ThemeConfig } from '@chakra-ui/react';

const config: ThemeConfig = {
  initialColorMode: 'light',
  useSystemColorMode: true,
};

const colors = {
  brand: {
    50: '#E6F3FF',
    100: '#BAE3FF',
    200: '#7CC4FA',
    300: '#47A3F3',
    400: '#2186EB',
    500: '#0967D2',
    600: '#0552B5',
    700: '#03449E',
    800: '#01337D',
    900: '#002159',
  },
  streaming: {
    live: '#FF4444',
    offline: '#666666',
    scheduled: '#FFA500',
  },
  subscription: {
    bronze: '#CD7F32',
    silver: '#C0C0C0',
    gold: '#FFD700',
  },
};

const fonts = {
  heading: `'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol"`,
  body: `'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol"`,
};

const components = {
  Button: {
    defaultProps: {
      colorScheme: 'brand',
    },
    variants: {
      solid: {
        bg: 'brand.500',
        color: 'white',
        _hover: {
          bg: 'brand.600',
        },
      },
      live: {
        bg: 'streaming.live',
        color: 'white',
        _hover: {
          bg: 'red.600',
        },
      },
    },
  },
  Card: {
    baseStyle: {
      container: {
        borderRadius: 'lg',
        boxShadow: 'sm',
        _hover: {
          boxShadow: 'md',
        },
      },
    },
  },
  Badge: {
    variants: {
      subscription: (props: any) => ({
        bg: `subscription.${props.colorScheme}`,
        color: 'white',
        textTransform: 'uppercase',
        fontWeight: 'bold',
      }),
      status: (props: any) => ({
        bg: `streaming.${props.colorScheme}`,
        color: 'white',
      }),
    },
  },
};

const styles = {
  global: (props: any) => ({
    body: {
      fontFamily: 'body',
      color: props.colorMode === 'dark' ? 'whiteAlpha.900' : 'gray.800',
      bg: props.colorMode === 'dark' ? 'gray.800' : 'white',
      lineHeight: 'base',
    },
    '*::placeholder': {
      color: props.colorMode === 'dark' ? 'whiteAlpha.400' : 'gray.400',
    },
    '*, *::before, &::after': {
      borderColor: props.colorMode === 'dark' ? 'whiteAlpha.300' : 'gray.200',
      wordWrap: 'break-word',
    },
  }),
};

export const theme = extendTheme({
  config,
  colors,
  fonts,
  components,
  styles,
});
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <png.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned channel(unsigned long pixel, unsigned long mask) {
  if (!mask) return 0;
  unsigned shift = (unsigned)__builtin_ctzl(mask);
  unsigned long maximum = mask >> shift;
  unsigned long value = (pixel & mask) >> shift;
  return (unsigned)((value * 255UL + maximum / 2UL) / maximum);
}

static uint32_t rgb(XImage *image, Visual *visual, int x, int y) {
  unsigned long pixel = XGetPixel(image, x, y);
  unsigned r = channel(pixel, visual->red_mask);
  unsigned g = channel(pixel, visual->green_mask);
  unsigned b = channel(pixel, visual->blue_mask);
  return ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
}

static int window_list(Display *display, Atom atom, Window *first,
                       unsigned long *count) {
  Window root = DefaultRootWindow(display);
  Atom actual_type = None;
  int actual_format = 0;
  unsigned long nitems = 0, bytes_after = 0;
  unsigned char *property = NULL;
  int status = XGetWindowProperty(display, root, atom, 0, 1024, False,
                                  XA_WINDOW, &actual_type, &actual_format,
                                  &nitems, &bytes_after, &property);
  if (status != Success || actual_type != XA_WINDOW || actual_format != 32 ||
      nitems == 0 || !property) {
    if (property) XFree(property);
    return 0;
  }
  if (first) *first = ((unsigned long *)property)[0];
  *count = nitems;
  XFree(property);
  return 1;
}

int main(int argc, char **argv) {
  const char *mode = argc > 1 ? argv[1] : "server";
  Display *display = XOpenDisplay(NULL);
  if (!display) {
    fprintf(stderr, "XOpenDisplay failed\n");
    return 2;
  }
  int screen = DefaultScreen(display);
  int width = DisplayWidth(display, screen);
  int height = DisplayHeight(display, screen);
  printf("X11_CONNECTION=ok\nDISPLAY=%s\nSCREEN=%dx%d\n",
         DisplayString(display), width, height);
  printf("SERVER_VENDOR=%s\nVENDOR_RELEASE=%d\n",
         XServerVendor(display), XVendorRelease(display));
  if (width != 1280 || height != 800) {
    fprintf(stderr, "unexpected screen size\n");
    XCloseDisplay(display);
    return 3;
  }
  if (strcmp(mode, "server") == 0) {
    XCloseDisplay(display);
    return 0;
  }
  if (strcmp(mode, "session") != 0 || argc != 3) {
    fprintf(stderr, "usage: %s server | session output.png\n", argv[0]);
    XCloseDisplay(display);
    return 2;
  }

  Atom wm_atom = XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", True);
  Window wm_window = 0;
  unsigned long wm_count = 0;
  if (wm_atom == None ||
      !window_list(display, wm_atom, &wm_window, &wm_count) || !wm_window) {
    fprintf(stderr, "missing _NET_SUPPORTING_WM_CHECK\n");
    XCloseDisplay(display);
    return 4;
  }
  printf("X11_WM_CHECK=present\nWM_CHECK_WINDOW=0x%lx\n", wm_window);
  char *wm_name = NULL;
  if (XFetchName(display, wm_window, &wm_name) > 0 && wm_name) {
    printf("WM_NAME=%s\n", wm_name);
    XFree(wm_name);
  } else {
    printf("WM_NAME=unavailable\n");
  }

  Atom clients_atom = XInternAtom(display, "_NET_CLIENT_LIST", True);
  unsigned long clients = 0;
  if (clients_atom == None ||
      !window_list(display, clients_atom, NULL, &clients) || clients < 1) {
    fprintf(stderr, "missing or empty _NET_CLIENT_LIST\n");
    XCloseDisplay(display);
    return 5;
  }
  printf("X11_CLIENT_COUNT=%lu\n", clients);

  Window root = RootWindow(display, screen);
  XSync(display, False);
  XImage *image = XGetImage(display, root, 0, 0, (unsigned)width,
                            (unsigned)height, AllPlanes, ZPixmap);
  if (!image) {
    fprintf(stderr, "XGetImage failed\n");
    XCloseDisplay(display);
    return 6;
  }
  Visual *visual = DefaultVisual(display, screen);
  png_image png;
  memset(&png, 0, sizeof(png));
  png.version = PNG_IMAGE_VERSION;
  png.width = (png_uint_32)width;
  png.height = (png_uint_32)height;
  png.format = PNG_FORMAT_RGB;
  size_t size = PNG_IMAGE_SIZE(png);
  png_bytep pixels = malloc(size);
  if (!pixels) {
    XDestroyImage(image);
    XCloseDisplay(display);
    return 6;
  }
  uint32_t background = rgb(image, visual, 0, 0);
  uint32_t seen[64];
  unsigned distinct = 0;
  unsigned long non_background = 0;
  size_t offset = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      uint32_t color = rgb(image, visual, x, y);
      pixels[offset++] = (png_byte)(color >> 16);
      pixels[offset++] = (png_byte)(color >> 8);
      pixels[offset++] = (png_byte)color;
      if (color != background) non_background++;
      unsigned i = 0;
      while (i < distinct && seen[i] != color) i++;
      if (i == distinct && distinct < 64) seen[distinct++] = color;
    }
  }
  XDestroyImage(image);
  int ok = png_image_write_to_file(&png, argv[2], 0, pixels,
                                   (png_int_32)(width * 3), NULL);
  if (!ok) fprintf(stderr, "PNG write failed: %s\n", png.message);
  png_image_free(&png);
  free(pixels);
  XCloseDisplay(display);
  if (!ok) return 7;
  printf("SCREENSHOT_PNG=%s\nSCREENSHOT_NON_BACKGROUND_PIXELS=%lu\n"
         "SCREENSHOT_DISTINCT_COLORS_CAPPED=%u\n",
         argv[2], non_background, distinct);
  if (non_background <= 1000 || distinct < 2) {
    fprintf(stderr, "screenshot appears blank\n");
    return 8;
  }
  return 0;
}

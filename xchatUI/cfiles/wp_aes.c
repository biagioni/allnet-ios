/* wp_aes.c: AES encryption */

/* this library is named for W. Wesley Peterson, who wrote the code this
 * library is loosely based on before he passed away in 2009 */
/* this AES code is basically Wes Peterson's code */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "wp_aes.h"

/* Things common to enciphering and deciphering */

/* GF(256) logarithm      */
static const int L[256] = {
	-1,   0xff, 0x19, 0x01, 0x32, 0x02, 0x1a, 0xc6, 
	0x4b, 0xc7, 0x1b, 0x68, 0x33, 0xee, 0xdf, 0x03, 
	0x64, 0x04, 0xe0, 0x0e, 0x34, 0x8d, 0x81, 0xef, 
	0x4c, 0x71, 0x08, 0xc8, 0xf8, 0x69, 0x1c, 0xc1, 
	0x7d, 0xc2, 0x1d, 0xb5, 0xf9, 0xb9, 0x27, 0x6a, 
	0x4d, 0xe4, 0xa6, 0x72, 0x9a, 0xc9, 0x09, 0x78, 
	0x65, 0x2f, 0x8a, 0x05, 0x21, 0x0f, 0xe1, 0x24, 
	0x12, 0xf0, 0x82, 0x45, 0x35, 0x93, 0xda, 0x8e, 
	0x96, 0x8f, 0xdb, 0xbd, 0x36, 0xd0, 0xce, 0x94, 
	0x13, 0x5c, 0xd2, 0xf1, 0x40, 0x46, 0x83, 0x38, 
	0x66, 0xdd, 0xfd, 0x30, 0xbf, 0x06, 0x8b, 0x62, 
	0xb3, 0x25, 0xe2, 0x98, 0x22, 0x88, 0x91, 0x10, 
	0x7e, 0x6e, 0x48, 0xc3, 0xa3, 0xb6, 0x1e, 0x42, 
	0x3a, 0x6b, 0x28, 0x54, 0xfa, 0x85, 0x3d, 0xba, 
	0x2b, 0x79, 0x0a, 0x15, 0x9b, 0x9f, 0x5e, 0xca, 
	0x4e, 0xd4, 0xac, 0xe5, 0xf3, 0x73, 0xa7, 0x57, 
	0xaf, 0x58, 0xa8, 0x50, 0xf4, 0xea, 0xd6, 0x74, 
	0x4f, 0xae, 0xe9, 0xd5, 0xe7, 0xe6, 0xad, 0xe8, 
	0x2c, 0xd7, 0x75, 0x7a, 0xeb, 0x16, 0x0b, 0xf5, 
	0x59, 0xcb, 0x5f, 0xb0, 0x9c, 0xa9, 0x51, 0xa0, 
	0x7f, 0x0c, 0xf6, 0x6f, 0x17, 0xc4, 0x49, 0xec, 
	0xd8, 0x43, 0x1f, 0x2d, 0xa4, 0x76, 0x7b, 0xb7, 
	0xcc, 0xbb, 0x3e, 0x5a, 0xfb, 0x60, 0xb1, 0x86, 
	0x3b, 0x52, 0xa1, 0x6c, 0xaa, 0x55, 0x29, 0x9d, 
	0x97, 0xb2, 0x87, 0x90, 0x61, 0xbe, 0xdc, 0xfc, 
	0xbc, 0x95, 0xcf, 0xcd, 0x37, 0x3f, 0x5b, 0xd1, 
	0x53, 0x39, 0x84, 0x3c, 0x41, 0xa2, 0x6d, 0x47, 
	0x14, 0x2a, 0x9e, 0x5d, 0x56, 0xf2, 0xd3, 0xab, 
	0x44, 0x11, 0x92, 0xd9, 0x23, 0x20, 0x2e, 0x89, 
	0xb4, 0x7c, 0xb8, 0x26, 0x77, 0x99, 0xe3, 0xa5, 
	0x67, 0x4a, 0xed, 0xde, 0xc5, 0x31, 0xfe, 0x18, 
    0x0d, 0x63, 0x8c, 0x80, 0xc0, 0xf7, 0x70, 0x07};

/* GF(256) antilogarithm  */
static const int F[256] = {
	0x01, 0x03, 0x05, 0x0f, 0x11, 0x33, 0x55, 0xff, 
	0x1a, 0x2e, 0x72, 0x96, 0xa1, 0xf8, 0x13, 0x35, 
	0x5f, 0xe1, 0x38, 0x48, 0xd8, 0x73, 0x95, 0xa4, 
	0xf7, 0x02, 0x06, 0x0a, 0x1e, 0x22, 0x66, 0xaa, 
	0xe5, 0x34, 0x5c, 0xe4, 0x37, 0x59, 0xeb, 0x26, 
	0x6a, 0xbe, 0xd9, 0x70, 0x90, 0xab, 0xe6, 0x31, 
	0x53, 0xf5, 0x04, 0x0c, 0x14, 0x3c, 0x44, 0xcc, 
	0x4f, 0xd1, 0x68, 0xb8, 0xd3, 0x6e, 0xb2, 0xcd, 
	0x4c, 0xd4, 0x67, 0xa9, 0xe0, 0x3b, 0x4d, 0xd7, 
	0x62, 0xa6, 0xf1, 0x08, 0x18, 0x28, 0x78, 0x88, 
	0x83, 0x9e, 0xb9, 0xd0, 0x6b, 0xbd, 0xdc, 0x7f, 
	0x81, 0x98, 0xb3, 0xce, 0x49, 0xdb, 0x76, 0x9a, 
	0xb5, 0xc4, 0x57, 0xf9, 0x10, 0x30, 0x50, 0xf0, 
	0x0b, 0x1d, 0x27, 0x69, 0xbb, 0xd6, 0x61, 0xa3, 
	0xfe, 0x19, 0x2b, 0x7d, 0x87, 0x92, 0xad, 0xec, 
	0x2f, 0x71, 0x93, 0xae, 0xe9, 0x20, 0x60, 0xa0, 
	0xfb, 0x16, 0x3a, 0x4e, 0xd2, 0x6d, 0xb7, 0xc2, 
	0x5d, 0xe7, 0x32, 0x56, 0xfa, 0x15, 0x3f, 0x41, 
	0xc3, 0x5e, 0xe2, 0x3d, 0x47, 0xc9, 0x40, 0xc0, 
	0x5b, 0xed, 0x2c, 0x74, 0x9c, 0xbf, 0xda, 0x75, 
	0x9f, 0xba, 0xd5, 0x64, 0xac, 0xef, 0x2a, 0x7e, 
	0x82, 0x9d, 0xbc, 0xdf, 0x7a, 0x8e, 0x89, 0x80, 
	0x9b, 0xb6, 0xc1, 0x58, 0xe8, 0x23, 0x65, 0xaf, 
	0xea, 0x25, 0x6f, 0xb1, 0xc8, 0x43, 0xc5, 0x54, 
	0xfc, 0x1f, 0x21, 0x63, 0xa5, 0xf4, 0x07, 0x09, 
	0x1b, 0x2d, 0x77, 0x99, 0xb0, 0xcb, 0x46, 0xca, 
	0x45, 0xcf, 0x4a, 0xde, 0x79, 0x8b, 0x86, 0x91, 
	0xa8, 0xe3, 0x3e, 0x42, 0xc6, 0x51, 0xf3, 0x0e, 
	0x12, 0x36, 0x5a, 0xee, 0x29, 0x7b, 0x8d, 0x8c, 
	0x8f, 0x8a, 0x85, 0x94, 0xa7, 0xf2, 0x0d, 0x17, 
	0x39, 0x4b, 0xdd, 0x7c, 0x84, 0x97, 0xa2, 0xfd, 
    0x1c, 0x24, 0x6c, 0xb4, 0xc7, 0x52, 0xf6, 0x01};

/* S-Box                  */
static const int SB[256] = {
	0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 
	0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76, 
	0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 
	0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0, 
	0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 
	0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15, 
	0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 
	0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75, 
	0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 
	0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84, 
	0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 
	0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf, 
	0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 
	0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8, 
	0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 
	0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2, 
	0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 
	0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73, 
	0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 
	0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb, 
	0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 
	0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, 
	0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 
	0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08, 
	0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 
	0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a, 
	0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 
	0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e, 
	0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 
	0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf, 
	0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 
    0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16};

#ifdef AES_DECRYPT
/* S-Box Inverse          */
static const int SBI[256] = {
	0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 
	0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb, 
	0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 
	0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb, 
	0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 
	0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e, 
	0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 
	0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25, 
	0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 
	0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92, 
	0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 
	0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84, 
	0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 
	0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06, 
	0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 
	0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b, 
	0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 
	0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73, 
	0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 
	0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e, 
	0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 
	0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b, 
	0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 
	0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4, 
	0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 
	0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f, 
	0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 
	0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef, 
	0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 
	0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61, 
	0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 
	0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d};
#endif /* AES_DECRYPT */

#define Nb    4
#define Nk    8
#define Nr   14

/* uint32_t w[60];  */  /* 60 = Nb*(Nr+1)  */

/* I will put the state in memory as an array of four  */
/* columns. The columns will be uint32_t's with the    */
/* first byte in the high order position.              */

/* uint32_t state[4]; */

static void AddRoundKey(uint32_t *state, int round, uint32_t *w)
{
  state[0] ^= w[Nb*round];;
  state[1] ^= w[Nb*round+1];
  state[2] ^= w[Nb*round+2];
  state[3] ^= w[Nb*round+3];
}

static int times(int x, int y)
{
  if(x==0 || y==0) return 0;
  return F[(L[x]+L[y])%255];
}

#ifdef DEBUG_PRINT
static void PrintState(uint32_t *s)
{
  int i;
  for(i = 0; i<4; i++) {
    printf("%02x%02x%02x%02x", 
	   *(s+i)>>24, (*(s+i)>>16)&0xff, (*(s+i)>>8)&0xff, (*(s+i))&0xff);
  }
  printf("\n");
}
#endif /* DEBUG_PRINT */

/* end of Wes's common.c */

/* start of Wes's KeyExpansion.c */

static uint32_t makeword(const unsigned char *p)
{
  uint32_t t;
  t = (((*p))<<24);
  t |= (0xff&*(p+1))<<16;
  t |= (0xff&*(p+2))<<8;
  t |= 0xff&*(p+3);
    
  return t;
}

static void SubWord(uint32_t *p)
{
  unsigned char *q = (unsigned char *) p;
  *q = SB[*q];
  *(q+1) = SB[*(q+1)];
  *(q+2) = SB[*(q+2)];
  *(q+3) = SB[*(q+3)];
}

static void RotWord(uint32_t *p)
{
  uint32_t t = (*p<<8) | (*p>>24);
  *p = t;
}

static void KeyExpansion(const unsigned char *key, uint32_t *w)
{
  int i;
  uint32_t temp;
  for(i = 0; i<Nk; i++)
    w[i] = makeword(key+4*i);

  for(i = Nk; i< Nb*(Nr+1); i++) {
    temp = w[i-1];
    if(i%Nk == 0) {
      RotWord(&temp);
      SubWord(&temp);
      temp ^= F[(L[0x02]*(i/Nk-1))%255]<<24;
    }
    else if(Nk==8 && i%4==0) SubWord(&temp);
    w[i] = w[i-Nk] ^ temp;
  }
}

/* end of Wes's KeyExpansion.c */

#ifdef AES_DECRYPT
/* start of Wes's AESD.c */

static void InvSubBytes(uint32_t *p)
{
  int i;
  unsigned char *q = (unsigned char *) p;
  for(i = 0; i<16; i++) *(q+i) = SBI[*(q+i)];
}
    
static void InvShiftRows(uint32_t *s)
{
  uint32_t a, b, c, d;
  a = s[0], b = s[1], c = s[2], d = s[3];
  s[0] = (a&0xff000000) | (d&0xff0000) | (c&0xff00) | (b&0xff);
  s[1] = (b&0xff000000) | (a&0xff0000) | (d&0xff00) | (c&0xff);
  s[2] = (c&0xff000000) | (b&0xff0000) | (a&0xff00) | (d&0xff);
  s[3] = (d&0xff000000) | (c&0xff0000) | (b&0xff00) | (a&0xff);
}

static uint32_t mcci(uint32_t x)
{
  int a, b, c, d, e, f, g, h;
  a = x>>24;
  b = (x>>16)&0xff;
  c = (x>>8)&0xff;
  d = x&0xff;

  e = times(0x0e,a)^times(0x0b,b)^times(0x0d,c)^times(0x09,d);
  f = times(0x09,a)^times(0x0e,b)^times(0x0b,c)^times(0x0d,d);
  g = times(0x0d,a)^times(0x09,b)^times(0x0e,c)^times(0x0b,d);
  h = times(0x0b,a)^times(0x0d,b)^times(0x09,c)^times(0x0e,d);

  return e<<24 | f<<16 | g<<8 | h;
}

static void InvMixColumns(uint32_t *s)
{
  s[0] = mcci(s[0]);
  s[1] = mcci(s[1]);
  s[2] = mcci(s[2]);
  s[3] = mcci(s[3]);
}

/* This function does the actual deciphering */
static void AESD(unsigned char *C, unsigned char *M,
                 uint32_t * w, uint32_t * state)
{
  int i, round;

  state[0] = makeword(C);
  state[1] = makeword(C+4);
  state[2] = makeword(C+8);
  state[3] = makeword(C+12);

  round = Nr;
  AddRoundKey(state, round, w);
#ifdef DEBUG_PRINT
  printf("start round=%d  ", round);
  PrintState(state);
#endif /* DEBUG_PRINT */
  InvShiftRows(state);
  InvSubBytes(state);

  for(round = Nr-1; round>0; round--) {
    AddRoundKey(state, round, w);
    InvMixColumns(state);
#ifdef DEBUG_PRINT
    printf("start round %d  ", round);
    PrintState(state);
#endif /* DEBUG_PRINT */
    InvShiftRows(state);
    InvSubBytes(state);
  }

  AddRoundKey(state, 0, w);

  for(i = 0; i<4; i++) {
    M[4*i] = state[i]>>24;
    M[4*i+1] = (state[i]>>16) & 0xff;
    M[4*i+2] = (state[i]>>8) & 0xff;
    M[4*i+3] = state[i] & 0xff;
  }
}
#endif /* AES_DECRYPT */

/* end of Wes's AESD.c */

/* start of Wes's AES.c */

static void SubBytes(uint32_t *p)
{
  int i;
  unsigned char *q = (unsigned char *) p;
  for(i = 0; i<16; i++) *(q+i) = SB[*(q+i)];
}
	
static void ShiftRows(uint32_t *s)
{
  uint32_t a, b, c, d;
  a = s[0], b = s[1], c = s[2], d = s[3];
  s[0] = (a&0xff000000) | (b&0xff0000) | (c&0xff00) | (d&0xff);
  s[1] = (b&0xff000000) | (c&0xff0000) | (d&0xff00) | (a&0xff);
  s[2] = (c&0xff000000) | (d&0xff0000) | (a&0xff00) | (b&0xff);
  s[3] = (d&0xff000000) | (a&0xff0000) | (b&0xff00) | (c&0xff);
}

static uint32_t mcc(uint32_t x)
{
  int a, b, c, d, e, f, g, h;
  a = x>>24;
  b = (x>>16)&0xff;
  c = (x>>8)&0xff;
  d = x&0xff;

  e = times(0x02,a)^times(0x03,b)^c^d;
  f = a^times(0x02,b)^times(0x03,c)^d;
  g = a^b^times(0x02,c)^times(0x03,d);
  h = times(0x03,a)^b^c^times(0x02,d);

  return e<<24 | f<<16 | g<<8 | h;
}
	
static void MixColumns(uint32_t *s)
{
  s[0] = mcc(s[0]);
  s[1] = mcc(s[1]);
  s[2] = mcc(s[2]);
  s[3] = mcc(s[3]);
}

static void AES(const unsigned char *M, unsigned char *C, uint32_t *w)
{
  int round, i;
  static uint32_t state[4];

  state[0] = makeword(M);
  state[1] = makeword(M+4);
  state[2] = makeword(M+8);
  state[3] = makeword(M+12);
  AddRoundKey(state, 0, w);

  for(round = 1; round<Nr; round++) {
#ifdef DEBUG_PRINT
    printf("Round %d  ", round);
    PrintState(state);
#endif /* DEBUG_PRINT */
    SubBytes(state);
    ShiftRows(state);
    MixColumns(state);
    AddRoundKey(state, round, w);
  }
#ifdef DEBUG_PRINT
  printf("Round %d  ", round);
  PrintState(state);
#endif /* DEBUG_PRINT */
  SubBytes(state);
  ShiftRows(state);
  AddRoundKey(state, round, w);
#ifdef DEBUG_PRINT
  printf("Output  ");
  PrintState(state);
#endif /* DEBUG_PRINT */
	
  for(i = 0; i<4; i++) {
    C[4*i] = state[i]>>24;
    C[4*i+1] = (state[i]>>16)&0xff;
    C[4*i+2] = (state[i]>>8)&0xff;
    C[4*i+3] = state[i]&0xff;
  }
}

/* end of Wes's AES.c */


/* for AES in counter mode, only encryption is used
 * in, out may be the same or different buffer, both should
 * have WP_AES_BLOCK_SIZE bytes
 * key size must be 32 bytes */
void wp_aes_encrypt_block (int ksize, const char * key,
                           const char * in, char * out)
{
  if (ksize != 32) {
    printf ("error: wp_aes_encrypt_block only supports 32-byte/256-bit key\n");
    printf ("       %d-byte key specified\n", ksize);
    exit (1);   /* this is a serious error in the caller */
  }
  uint32_t w[60];  /* 60 = Nb*(Nr+1)  */
  /* uint32_t state[4]; */
  KeyExpansion((const unsigned char *) key, w);
  AES ((const unsigned char *) in, (unsigned char *) out, w);
}

#ifdef AES_UNIT_TEST
int main (int argc, char ** argv)
{
  char key [] =   /* not random */
   {  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16,
     17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};

  /* ECBVarTxt256.rsp, test 1, the key is all zeros */
  memset (key, 0, sizeof (key));
  char data [WP_AES_BLOCK_SIZE];
  memset (data, 0, sizeof (data));
  data [0] = 0x80;
  char result [WP_AES_BLOCK_SIZE];
  char expected [] = { 0xdd, 0xc6, 0xbf, 0x79, 0x0c, 0x15, 0x76, 0x0d,
                       0x8d, 0x9a, 0xeb, 0x6f, 0x9a, 0x75, 0xfd, 0x4e };

  wp_aes_encrypt_block (32, key, data, result);
  if (memcmp (expected, result, sizeof (result)) != 0) {
    printf ("error: AES did not give the right result\n");
    return 1;
  }
  printf ("AES test was successful\n");
  return 0;
}
#endif /* AES_UNIT_TEST */
